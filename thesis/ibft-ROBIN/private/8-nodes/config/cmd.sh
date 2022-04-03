#!/bin/bash
command=$1
node=$2

if [ $# -lt 2 ]
  then
    echo "Arguments number not correct!"
    echo "Usage: ./cmd.sh COMMAND NODE_ID"
fi

if [[ "$command" = "console" ]]; then 
    container_id=`docker ps --format "{{.ID}}:{{.Names}}" | grep node_$node | cut -d : -f 1`
    if [[ "$container_id" = "" ]]; then
        echo "No such container."
        exit 1
    fi
    echo "..... Connecting to node_$node geth console ....."
    docker exec -it $container_id bash -c "export SHELL=/bin/bash && geth attach /qdata/dd/geth.ipc"
    exit 0
fi