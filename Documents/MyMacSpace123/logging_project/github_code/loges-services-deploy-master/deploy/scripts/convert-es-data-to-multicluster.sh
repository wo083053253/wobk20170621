#!/bin/bash
#set -x

# setup ssh cmd
SSH_KEY="/home/stack/.ssh/id_rsa"
SSH_USER="stack"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=1200"
SSH_CMD="ssh ${SSH_OPTIONS} -i ${SSH_KEY}"

# convert the data folders for the given role
convert() {
    ROLE=$1

    ES_HOST="/opt/deploy/hosts/${ROLE}"
    [[ ! -f "${ES_HOST}" ]] && echo "Error finding file ${ES_HOST}" && exit 1

    # iterate through all the hosts in the given role
    for i in $(cat ${ES_HOST}); do
        if [[ $i != *"_servers"* ]]; then
            echo "Converting ${ROLE} IP: ${i}"
            ${SSH_CMD} ${SSH_USER}@$i sudo mv /elasticsearch/elasticsearch /elasticsearch/elasticsearch_1
        fi
    done
}


convert elasticsearch_master_1
convert elasticsearch_data_hot_1
convert elasticsearch_data_warm_1
