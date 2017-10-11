#!/bin/bash

[ $# -gt 0 ] || ( echo "Usage clusterRegister.sh <cluster name>" && exit -1 )
cluster=$1

cd `dirname $0`/../

echo "Process cluster $cluster"

cluster_key_in_node_name="${cluster//_/-}"
nodes=`ls nodes/*${cluster_key_in_node_name}*`

# echo "Nodes : $nodes"

for node in $nodes; do
   echo "Processing node : $node"

   name=`echo "$node" | cut -d\/ -f2`

   source $node

   scripts/register.sh $cluster $name $address $restart_url
	# register one node will trigger configuration update to all the nodes
	exit 0
done;
