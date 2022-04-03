#!/bin/bash

#
# This is used at Container start up to run the Tessera and geth nodes
#

set -u
set -e

### Configuration Options
TMCONF=/qdata/config.json

#GETH_ARGS="--datadir /qdata/dd --raft --rpc --rpcaddr 0.0.0.0 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum --nodiscover --unlock 0 --password /qdata/passwords.txt"
GETH_ARGS="--datadir /qdata/dd --rpcport {rpc_port} --port {rlp_port} --raftport {raft_port} --identity {node_name} --raft --rpc --rpccorsdomain=* --rpcaddr 0.0.0.0 --rpcvhosts=* --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,clique,raft,istanbul --ws --wsaddr 0.0.0.0 --wsorigins=* --wsapi eth,web3,quorum,txpool,net --wsport {ws_port} --unlock 0 --password /qdata/passwords.txt --networkid 10 {bootnode}"


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