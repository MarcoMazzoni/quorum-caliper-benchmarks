#!/bin/bash

echo "  - Removing containers"
docker-compose --log-level ERROR down 2>/dev/null

echo "  - Removing old data"
rm -rf qdata_[0-9] qdata_[0-9][0-9]
rm -f docker-compose.yml
rm -f private_contract.js public_contract.js

echo "  - Cleaning up peer list in config.json"
sed -i '/"peer":\[/,/\]/{//!d}' utils/config.json
