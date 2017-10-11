#!/bin/bash

set -eux

cd /opt/deploy/nodes/
for i in `ls | grep eventgen-rest `
do
   echo "ready to update REST server on $i"
   /opt/deploy/scripts/config_node.sh eventgen_rest $i
done

