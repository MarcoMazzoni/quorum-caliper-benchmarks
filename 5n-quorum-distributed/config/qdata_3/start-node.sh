#!/bin/bash

#
# This is used at Container start up to run the Tessera and geth nodes
#

set -u
set -e

### Configuration Options
TMCONF=/qdata/config.json

#GETH_ARGS="--datadir /qdata/dd --istanbul.blockperiod 1 --syncmode full --mine --minerthreads 1  --rpc --rpcaddr 0.0.0.0 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum --nodiscover --unlock 0 --password /qdata/passwords.txt"
GETH_ARGS="--datadir /qdata/dd --rpcport 8545 --port 30303 --raftport 50400 --identity master-3 --istanbul.blockperiod 1 --syncmode full --mine --minerthreads 1  --rpc --rpccorsdomain=* --rpcaddr 0.0.0.0 --rpcvhosts=* --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,clique,raft,istanbul --ws --wsaddr 0.0.0.0 --wsorigins=* --wsapi eth,web3,quorum,txpool,net --wsport 8546 --unlock 0 --password /qdata/passwords.txt --networkid 10 --bootnodes enode://f447aa9445d7ed531c01cea922e92a8ac03d6afceeb5498cbc1bc999bf1f5f7ba5345f9b3dce201c10a00fe9331453592cac1f2596df421cf217932b677bd216@172.13.0.2:30303,enode://66e079a93b28bfc4e3178464389da3561119ad5bf0336092c9b52747ff70408ef8f55277f322a641a678446b41140f440c1cb851c1289d1c13a65d073c5f142b@172.13.0.3:30303,enode://53d10426b6cd71bbe339a9c4693411480391dcbd4a6d1c42e31c2daa4316bae45c9d885a18e1ea94960d2f291146459c732e148150b981a251df62d739ea7ca0@172.13.0.4:30303,enode://c3456b62e46d3ed792df80b4815545ae5bbfe28e079eb167ec3050bec7d7449d22dc4aed33300900ba1e6910c2875d8e213a863bd480221e4ce74c8ae0197510@172.13.0.5:30303,enode://249025972998b3b7fca56523a93feae379a829435a7a1e68f721a7bba299a886bb29ee6130c006e962157a9dfb9c8ebbc0cf857440959341bcad070540d39df0@172.13.0.6:30303"


if [ ! -d /qdata/dd/geth/chaindata ]; then
  echo "[*] Mining Genesis block"
  /usr/local/bin/geth --datadir /qdata/dd init /qdata/genesis.json
fi

# echo "[*] Starting Constellation node"
# nohup /usr/local/bin/constellation-node $TMCONF 2>> /qdata/logs/constellation.log &

echo "[*] Starting Tessera node"
java -jar /tessera/tessera-app.jar -configfile $TMCONF >> /qdata/logs/tessera.log 2>&1 &

sleep 60

echo "[*] Starting Geth node"
PRIVATE_CONFIG=/qdata/tm.ipc nohup /usr/local/bin/geth $GETH_ARGS 2>>/qdata/logs/geth.log