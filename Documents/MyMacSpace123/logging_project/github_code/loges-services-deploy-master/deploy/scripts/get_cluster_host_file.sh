#!/bin/bash
#set -x


ROLE=$1
CLUSTER_NUM=$2

host_file_name=$ROLE

# Check if multi_cluster is enabled
declare -A multicluster=([elasticsearch_master]=1 [elasticsearch_http]=1 [elasticsearch_data_hot]=1 [elasticsearch_data_warm]=1)

MULTI_CLUSTER_ENABLED=$(grep "MULTI_CLUSTER_ES_ENABLED" /opt/deploy/group_vars/all | awk -F ": " '{print $2}')

if [[ "$MULTI_CLUSTER_ENABLED" -eq 1 ]]; then
    if [[ ${multicluster[$ROLE]} ]]; then
        if [ -z "$CLUSTER_NUM" ]; then
            echo "Usage: $0 <role>  <cluster_num>"
            exit 1
        fi
        host_file_name=${ROLE}_${CLUSTER_NUM}
    fi
fi

echo "$host_file_name"
