#!/bin/bash

`docker-compose down -v` && cd ./config && `docker-compose down -v` && cd ..
