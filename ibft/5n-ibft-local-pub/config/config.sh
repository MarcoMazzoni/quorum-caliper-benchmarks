
#!/bin/bash

#### Configuration options #############################################

# Host ports
rpc_start_port=23000
node_start_port=24000
raft_start_port=25000
ws_start_port=26000
tessera_start_port=27000

# Containers ports
raft_port=50400
tessera_port=9000
rlp_port=30303
rpc_port=8545
ws_port=8546

# VIP Subnet
subnet="172.13.0.0/16"

# Total nodes to deploy
total_nodes=5

# Signer nodes for IBFT
signer_nodes=5

# Consensus engine ex. raft, istanbul
consensus=raft

# Block period for IBFT
block_period=0

# Docker image name -> quorum-ibft-new, quorum-raft-ibft, quorum-2.5.0
image=quorum-2.5.0

# Service name for docker-compose.yml
service=n1

# Send some ether for pre-defined accounts
alloc_ether=true

# Create deterministic accounts for testing purpose
fixed_accounts=true

# Create deterministic Tessera keys for testing purpose
fixed_tessera_keys=true

node_name_prefix=master
auto_start_containers=false

########################################################################

[[ "$total_nodes" -lt "$signer_nodes" ]] && total_nodes=$signer_nodes