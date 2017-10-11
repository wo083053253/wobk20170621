#!/bin/bash

set -eux

for i in `ls /opt/deploy/nodes/*eventgen-rest*`
do
    ip=`cat $i | grep address | cut -d "=" -f 2 | tr -d "'"`
    ssh -o StrictHostKeyChecking=no $ip sudo docker restart -t 1 eventgen_rest
    sleep 1
done


