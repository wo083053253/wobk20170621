#!/bin/bash
set -x
manager_ip=$1
hostname=$2
role=$3
virtual_ip=$4

function write_inventory() {
    item=$1
    su - ubuntu -c "ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip" << EOF
        echo "$virtual_ip" > /opt/deploy/vips/${item}
EOF
}

echo "Starting vip_update at [`date`]"

write_inventory $role

echo "End vip_update at [`date`]"
