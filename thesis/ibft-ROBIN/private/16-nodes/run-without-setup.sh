#!/bin/bash

MASTER="caliper_master"
WORKER1="caliper_worker_1"
WORKER2="caliper_worker_2"
WORKER3="caliper_worker_3"

wait_function() {
  last_log="Generated report with path"
  echo "Waiting for $MASTER & workers to finish the benchmark...."
  echo "It can take a few minutes...."
  while ! `cat output_$MASTER.log | egrep -q "$last_log"` ; do
    echo -n " . "
    sleep 1
  done 
}

# Print all commands.
set -v

curr_dir=`pwd`

## Starting up the Quorum network
cd 'config' && `docker-compose up -d`

cd $curr_dir

## Waiting for the nodes to start up  all the services keys
sleep 3

## Starting up the benchmarking cluster
`docker-compose up -d` 

############# Printing out caliper master output #############

`docker logs -f $MASTER &> output_$MASTER.log ` 2>&1 &
`docker logs -f $WORKER1 &> output_$WORKER1.log ` 2>&1 &
`docker logs -f $WORKER2 &> output_$WORKER2.log ` 2>&1 &
`docker logs -f $WORKER3 &> output_$WORKER3.log ` 2>&1 &

wait_function &

wait 

echo "Output files and report.html printed out! You can check them out."







