#!/bin/bash

if [[ ! -f blocked.yml ]]; then
    echo "No blocked.yml file. See blocked.yml.example for use"
    exit 1
fi

ansible-playbook -i /opt/deploy/hosts/.all update_blocks.yml
