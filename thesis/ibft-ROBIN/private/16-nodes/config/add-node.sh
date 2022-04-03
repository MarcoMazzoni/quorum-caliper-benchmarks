#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Usage: ./add-node.sh NODE_ID"
    echo "NODE_ID must be an integer number"
    exit 1
fi

node=$1

container_id=`docker ps --format "{{.ID}}:{{.Names}}" | grep node_$node | cut -d : -f 1`
if [[ ! "$container_id" = "" ]]; then
    echo "Node $node already exists in the network! Choose another ID number."
    exit 2
fi

new_ip=$(./utils/ip_gen.sh)


