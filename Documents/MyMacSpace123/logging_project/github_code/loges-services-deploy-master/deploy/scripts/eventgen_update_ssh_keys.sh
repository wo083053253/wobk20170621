#!/bin/bash
set -x

{
    flock 100
    # Enter the /opt/deploy directory
    cd `dirname $0`/../

    # create temp_inventory for all eventgen hosts
    cat hosts/yarn_master > temp_inventory
    cat hosts/yarn_slave >> temp_inventory
    cat hosts/eventgen_rest >> temp_inventory

    date >> /var/log/ansible/playbook.log

    ansible-playbook -vvv -i temp_inventory eventgen_update_ssh_keys.yml >> /var/log/ansible/playbook.log

    flock -u 100
} 100<>/tmp/register.lock
