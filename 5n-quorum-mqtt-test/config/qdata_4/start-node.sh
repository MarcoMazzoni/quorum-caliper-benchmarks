#!/bin/bash

#
# This is used at Container start up to run the Tessera and geth nodes
#

set -u
set -e

### Configuration Options
TMCONF=/qdata/config.json

#GETH_ARGS="--datadir /qdata/dd --istanbul.blockperiod 1 --syncmode full --mine --minerthreads 1  --rpc --rpcaddr 0.0.0.0 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum --nodiscover --unlock 0 --password /qdata/passwords.txt"
GETH_ARGS="--datadir /qdata/dd --rpcport 8545 --port 30303 --raftport 50400 --identity master-4 --istanbul.blockperiod 1 --syncmode full --mine --minerthreads 1  --rpc --rpccorsdomain=* --rpcaddr 0.0.0.0 --rpcvhosts=* --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,clique,raft,istanbul --ws --wsaddr 0.0.0.0 --wsorigins=* --wsapi eth,web3,quorum,txpool,net --wsport 8546 --unlock 0 --password /qdata/passwords.txt --networkid 10 --bootnodes enode://fa6b56d0a5bfe1433ac85ab98fa23e414a27abeb4d31927b5faceb6b1e4a3bc8586babbe77f6389df4bdfb5b4d6e82d93b84ab49288109b9c811179aa090d506@172.13.0.2:30303,enode://64c1c1b651221f8b1e921fcb54c99c73df639bf543b12fe4130cc9af79364a5968228e0c2d8986108f796b255d8f16af15e5561521014a391b2be00b59b4c861@172.13.0.3:30303,enode://e8576498fc8c2cb051179971975229d7396bdadb0a98e8adee57fdc6a1084a2162d84e5a234746f8ba0e029f6cb3477c78a7870597ec18d34f6d9b73d2cca867@172.13.0.4:30303,enode://995d4706c531b101a7810dd61d14000efcd56813bdbd48f5e99702b79e150887c873a9fe7ecfb2084df12bfc46f6fc952adc8b362d001cf42a16949985070302@172.13.0.5:30303,enode://42084d3de15a2ec2436ced599c11a032feb21f3104ee6aca071493ee28ae4673f32e558bc64e144babbc169d937894d287b0d957dd5b8f3b4223c1ff21b70d78@172.13.0.6:30303"


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