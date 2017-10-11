#!/bin/bash
set -x
manager_ip=$1
role=$2
role_list=$3
floating_ip=$4
virtual_ip=$5

function write_inventory() {
    item=$1
    su - stack -c "ssh stack@$manager_ip" << EOF
        echo "$floating_ip" > /opt/deploy/floatings/${item}
        echo "$virtual_ip" > /opt/deploy/vips/${item}
EOF
}

echo "Starting floating_update at [`date`]"

if [[ -n "$role_list" ]]; then
    for item in ${role_list//,/ }; do
        write_inventory $item
    done
else
    write_inventory $role
fi

echo "End floating_update at [`date`]"
