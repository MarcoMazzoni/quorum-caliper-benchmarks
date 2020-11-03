#!/bin/bash
#
# Create all the necessary scripts, keys, configurations etc. to run
# a cluster of N Quorum nodes with Raft consensus.
#
# The nodes will be in Docker containers. List the IP addresses that
# they will run at below (arbitrary addresses are fine).
#
# Run the cluster with "docker-compose up -d"
#
# Geth and Tessera logfiles for Node N will be in qdata_N/logs/
#

# TODO: check file access permissions, especially for keys.


#### Color Control Codes ###############################################

COLOR_RESET='\e[0m'
COLOR_GREEN='\e[1;32m';
COLOR_RED='\e[1;31m';
COLOR_YELLOW='\e[1;33m';
COLOR_BLUE='\e[1;36m';
COLOR_WHITE='\e[1;37m';


#### Configuration options #############################################

# One Docker container will be configured for each IP address in $ips

# Please edit config.sh for cluster configuration.
source ./config.sh

########################################################################

ip_prefix="`echo ${subnet} | cut -d / -f 1 | cut -d . -f 1-3`."

ips=()
signer_ips=()

n=0

[[ ! "$1" = "" ]] && consensus=$1

if [ "${consensus}" = "clique" ]; then
    echo -e "${COLOR_WHITE}[*] Deploy ${COLOR_BLUE}Quorum${COLOR_WHITE} with ${COLOR_YELLOW}Clique${COLOR_WHITE} consensus engine${COLOR_RESET}"
elif [ "${consensus}" = "istanbul" ]; then
    echo -e "${COLOR_WHITE}[*] Deploy ${COLOR_BLUE}Quorum${COLOR_WHITE} with ${COLOR_GREEN}Istanbul BFT${COLOR_WHITE} consensus engine${COLOR_RESET}"
elif [ "${consensus}" = "raft" ]; then
    echo -e "${COLOR_WHITE}[*] Deploy ${COLOR_BLUE}Quorum${COLOR_WHITE} with ${COLOR_RED}Raft${COLOR_WHITE} consensus engine${COLOR_RESET}"
else
    echo -e "${COLOR_WHITE}Consensus engine not found: ${COLOR_RED}${consensus}${COLOR_WHITE}${COLOR_RESET}"
fi

if [[ "$total_nodes" -lt "2" ]]
then
    echo "ERROR: There must be more than one node."
    exit 1
fi

if [[ ! "${consensus}" = "raft" &&  "$signer_nodes" -lt "4" ]]
then
    echo "ERROR: There must be at least four signer nodes in IBFT and Clique consensus ."
    exit 1
fi

if [ -e docker-compose.yml ]; then
    echo -e "${COLOR_WHITE}[*] Performing cleanup. ${COLOR_RESET}"
    ./cleanup.sh
fi

uid=`id -u`
gid=`id -g`
pwd=`pwd`

#### Create directories for each node's configuration ##################

# Force cleanup on next setup
touch docker-compose.yml

cp config.sh .current_config

i=0
n=0

# Fill IP list
# The loop starts from i=2 and stops to i=(total_nodes+1)
for i in $(seq 2 $((total_nodes+1))); do
    ips+=("$ip_prefix$i") 
    if [[ ! "${consensus}" = "raft" && "$n" -ge "$((total_nodes-signer_nodes))" ]]; then
        signer_ips+=("$ip_prefix$i")
    fi
    let n++
done

printf "${COLOR_WHITE}[1] Configuring for ${COLOR_RED}'$total_nodes'${COLOR_WHITE} nodes"
if [ ! "${consensus}" = "raft" ]; then
    printf " with ${COLOR_YELLOW}'${#signer_ips[@]}'${COLOR_WHITE} signer nodes"
fi

echo -e ".${COLOR_RESET}"

# Create directories
n=1
for ip in ${ips[*]}
do
    qd=qdata_$n
    mkdir -p $qd/{logs,keys}
    mkdir -p $qd/dd/geth

    let n++
done


#### Make static-nodes.json and store keys #############################

nodekeys=""

echo -e "${COLOR_WHITE}[2] Creating Enodes and static-nodes.json.${COLOR_RESET}"

bootnode=""

master_enodes="master_enodes=(\n"

echo "[" > static-nodes.json
n=1
for ip in ${ips[*]}
do
    if [ "$use_host_net" = "true" ]; then
        ip=$interface_ip
        rpc_port=$((n+rpc_start_port))
        raft_port=$((n+raft_start_port))
        rlp_port=$((n+node_start_port))
	    ws_port=$((n+node_ws_port))
    fi
    
    qd=qdata_$n

    # Comma separator for IBFT nodekeys list
    sep=`[[ $n -lt $total_nodes ]] && echo ","`

    # Generate the node's Enode and key
    nkey=`docker run --net=host --rm -u $uid:$gid -v $pwd/$qd:/qdata $image sh -c "/usr/local/bin/bootnode -genkey /qdata/dd/nodekey -writeaddress; cat /qdata/dd/nodekey"`

    # IBFT uses nodekeys to authorize nodes.
    if [ "$consensus" = "istanbul" ]; then
        nodekeys="${nodekeys}${nkey}${sep}"
    fi

    enode=`docker run --net=host --rm -u $uid:$gid -v $pwd/$qd:/qdata $image sh -c "/usr/local/bin/bootnode -nodekeyhex ${nkey} -writeaddress"`
    
    # Add the enode to static-nodes.json
    echo '  "enode://'$enode'@'$ip':'$rlp_port'?raftport='$raft_port'"'$sep >> static-nodes.json
    
    bootnode="${bootnode}enode:\\/\\/${enode}@${ip}:${rlp_port}$sep"

    master_enodes="${master_enodes}${enode}\n"

    echo -e "  - ${COLOR_GREEN}Node #${n}${COLOR_RESET} with nodekey: ${COLOR_YELLOW}${enode:0:8}...${enode:120:8}${COLOR_RESET} configured."

    let n++
done

master_enodes="$master_enodes)"

echo "]" >> static-nodes.json

echo -e "\n\n\n$master_enodes" >> .current_config


#### Create accounts, keys and genesis.json file #######################

echo -e "${COLOR_WHITE}[3] Creating Ethereum accounts and genesis.json.${COLOR_RESET}"

# extraData parameter for IBFT
istanbul_extra=""

cat > genesis.json <<EOF
{
  "alloc": {
EOF

# Create extraData from nodekeys
if [ "$consensus" = "istanbul" ]; then
    genesis=`docker run --net=host --rm $image sh -c "istanbul reinit --nodekey ${nodekeys} --quorum"`
    istanbul_extra=`echo $genesis | grep -Po '"extraData": "0x[0-9a-f]+",' | cut -d \" -f 4`
    validators=($(echo $genesis | grep -Po '"[0-9a-f]{40}":' | cut -c 2-41))
    for addr in ${validators[*]}; do
        cat >> genesis.json <<EOF
    "$addr": {
      "balance": "0x446c3b15f9926687d2c40534fdb564000000000000"
    },
EOF
    done
fi

n=1
signers=""
for ip in ${ips[*]}
do
    qd=qdata_$n

    # Generate an Ethereum account from the private key (deterministic account -> generates always accounts with the same addresses)
    # It'll generate as many accounts as keystore files provided (if you provide 5 keystore files, you can't generate more than 5 nodes -> 1 account per node)
    if [ "$fixed_accounts" = "true" ]; then
      mkdir -p $qd/dd/keystore
      cp ./keyfiles/keystore$n/key.prv $qd/dd/keystore/key.prv
      touch $qd/passwords.txt
      account=`docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/geth --datadir=/qdata/dd --password /qdata/passwords.txt account list | cut -c 14-53`
      printf "  - Account ${COLOR_YELLOW}0x${account}${COLOR_RESET} imported on ${COLOR_GREEN}Node #${n}${COLOR_RESET}."
    else
    # Generate a random Ethereum account for the node
      touch $qd/passwords.txt
      account=`docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/geth --datadir=/qdata/dd --password /qdata/passwords.txt account new | cut -c 11-50`
      printf "  - Account ${COLOR_YELLOW}0x${account}${COLOR_RESET} created on ${COLOR_GREEN}Node #${n}${COLOR_RESET}."
    fi

    # If current IP matches (regex) the signer_ip, then add the current created account to the signers account list
    if [[ " ${signer_ips[@]} " =~ " $ip " ]]; then
        if [ "${consensus}" = "clique" ]; then
            signers="${account}${signers}"
        fi
	      printf " ${COLOR_RED}(Signer)${COLOR_RESET}"
    fi

    printf "\n" 

    # Add the account to the genesis block so it has some Ether at start-up
    sep=`[[ $n -lt $total_nodes ]] && echo ","`
    
    if [ "$alloc_ether" = "true" ]; then
      cat >> genesis.json <<EOF
      "${account}": {
        "balance": "1000000000000000000000000000"
      }${sep}
EOF
    fi

    let n++
done

cat >> genesis.json <<EOF
  },
  "coinbase": "0x0000000000000000000000000000000000000000",
  "difficulty": "0x1",
  "gasLimit": "0xE0000000",
  "nonce": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "timestamp": "0x`printf "%x" $(date +%s)`",
EOF

cat >> genesis.json <<EOF
   "config":{
    "chainId": 10,
    "eip150Block": 1,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip155Block": 1,
    "eip158Block": 1,
    "byzantiumBlock": 1,
    "constantinopleBlock": 1,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "homesteadBlock": 0,
    "maxCodeSizeConfig" : [
      {
        "block" : 0,
        "size" : 128
      }
    ],
    "txnSizeLimit": 128,
    "maxCodeSize": 128,
    "maxCodeSizeChangeBlock": 0,
EOF

# Clique
if [ "${consensus}" = "clique" ]; then
    cat >> genesis.json <<EOF
    "isQuorum": true,
    "clique": {
      "period": ${block_period},
      "epoch": 30000
    }
  },
  "extraData": "0x0000000000000000000000000000000000000000000000000000000000000000${signers}0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
EOF

#IBFT
elif [ "${consensus}" = "istanbul" ]; then
    cat >> genesis.json <<EOF
    "isQuorum": true,
    "istanbul": {
      "epoch": 30000,
      "policy": 0,
      "ceil2Nby3Block": 0
    }
  },
  "gasUsed": "0x0",
  "number": "0x0",
  "extraData": "${istanbul_extra}",
  "mixHash": "0x63746963616c2062797a616e74696e65206661756c7420746f6c6572616e6365"
}
EOF

# Raft
else 
    cat >> genesis.json <<EOF
    "isQuorum": true
  },
  "extraData": "0x",
  "mixhash": "0x00000000000000000000000000000000000000647572616c65787365646c6578"
}
EOF
fi


#### Complete each node's configuration ################################

echo -e "${COLOR_WHITE}[4] Creating Tessera keys and config.json - finishing configuration.${COLOR_RESET}"

#### Add peers to config.json ########################################

n=1
for ip in ${ips[*]}
do
    qd=qdata_$n
    
    sep=`[[ $n > 1 ]] && echo ","`
    myline1='"url": "http://'
    myline1+="$ip:$tessera_port"
    myline1+='"'
    #myline1+=$sep

echo "    Adding peers to Tessera config file:"
echo $myline1
    sed -i "/peer/ a {\n\t\t$myline1\n\t}$sep" utils/config.json
    let n++
done


tessera_keys="tessera_keys=(\n"
n=1
for ip in ${ips[*]}
do
    qd=qdata_$n

    cat utils/config.json | sed s/_NODEIP_/${ips[$((n-1))]}/g > $qd/config.json

    cp genesis.json $qd/genesis.json
    cp static-nodes.json $qd/dd/static-nodes.json

    if [ "$fixed_tessera_keys" = "true" ]; then
      mkdir -p $qd/keys
      cp ./keyfiles/keystore$n/tm.key $qd/keys/tm.key
      cp ./keyfiles/keystore$n/tm.pub $qd/keys/tm.pub
    else
      # Generate Quorum-related keys (used by Tessera)
      docker run -u $uid:$gid -v $pwd/$qd:/qdata $image java -jar /tessera/tessera-app.jar -keygen -filename /qdata/keys/tm < /dev/null > /dev/null
    fi
    pubkey=`cat $qd/keys/tm.pub`
    echo -e "  - ${COLOR_GREEN}Node #$n${COLOR_RESET} public key for Tessera: ${COLOR_YELLOW}$pubkey${COLOR_RESET}"


    cat utils/start-node.sh \
        | sed s/{raft_port}/${raft_port}/g \
        | sed s/{rpc_port}/${rpc_port}/g \
        | sed s/{rlp_port}/${rlp_port}/g \
	      | sed s/{ws_port}/${ws_port}/g \
        | sed "s/{node_name}/${node_name_prefix}-$n/g" \
        | sed "s/{bootnode}/--bootnodes ${bootnode}/g" \
            > $qd/start-node.sh

    chmod 755 $qd/start-node.sh

    # Set custom raftblocktime when using Raft consensus
     if [ "${consensus}" = "raft" ]; then
        sed -i "s/--raft /--raft --raftblocktime ${raft_block_time} /g" $qd/start-node.sh

    #Do fullsync and mining on clique signer  
    elif [ "${consensus}" = "clique" ]; then

        sed -i 's/--raft /--syncmode full /g' $qd/start-node.sh

	    if [[ " ${signer_ips[@]} " =~ " $ip " ]]; then
            sed -i 's/full/full --mine/g' $qd/start-node.sh    
      fi

    elif [ "${consensus}" = "istanbul" ]; then

      #Block period must be > 1 in IBFT
      [[ $block_period < 1 ]] && block_period=1

	    sed -i "s/--raft /--istanbul.blockperiod ${block_period} --syncmode full /g" $qd/start-node.sh

	    if [[ " ${signer_ips[@]} " =~ " $ip " ]]; then
            sed -i 's/full/full --mine --minerthreads 1 /g' $qd/start-node.sh
      fi

    fi

    tessera_keys="${tessera_keys}${pubkey}\n"

    let n++
done

tessera_keys="$tessera_keys)"
echo -e "\n\n$tessera_keys" >> .current_config

rm -rf genesis.json static-nodes.json


#### Create the docker-compose file ####################################

cat > docker-compose.yml <<EOF
version: '3.6'
services:
EOF

n=1
for ip in ${ips[*]}
do
    qd=qdata_$n

    cat >> docker-compose.yml <<EOF
  node_${consensus}_$n:
    image: $image
    volumes:
      - './$qd:/qdata'
      - '/etc/localtime:/etc/localtime'
    networks:
      quorum_net:
        ipv4_address: '$ip'
    ports:
      - $((n+rpc_start_port)):8545
      - $((n+node_start_port)):30303
      - $((n+raft_start_port)):50400
      - $((n+ws_start_port)):8546
      - $((n+tessera_start_port)):9081
    user: '$uid:$gid'
EOF

    let n++
done

cat >> docker-compose.yml <<EOF
networks:
  quorum_net:
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: $subnet
EOF

# Start Cluster
if [[ "$auto_start_containers" = "true" ]]; then
    echo -e "${COLOR_WHITE}[5] Starting Quorum cluster.${COLOR_RESET}"
    docker-compose up -d 2>/dev/null
fi

echo -e "${COLOR_WHITE}[-] Finished.${COLOR_RESET}"
