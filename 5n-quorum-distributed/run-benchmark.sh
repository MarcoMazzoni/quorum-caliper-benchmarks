#!/bin/bash

# Print all commands.
set -v

curr_dir=`pwd`

cd 'config' && `docker-compose up -d`
cd $curr_dir

sleep 70

`docker-compose up -d`


