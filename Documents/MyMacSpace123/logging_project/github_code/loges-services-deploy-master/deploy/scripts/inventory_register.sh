#!/bin/bash
set -x
manager_ip=$1
hname=$2
role=$3
cluster_num=$4
cluster_name=$5

declare -A elasticsearch_cluster=([elasticsearch_master]=1 [elasticsearch_http]=1 [elasticsearch_data_hot]=1 [elasticsearch_data_warm]=1 [elasticsearch_lb]=1 [logstash]=1 [logstash_fastforwarder]=1 [logstash_objstore]=1)
host_file_name=$role # Copy the role variable in case an elasticsearch component is being registered
addr=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
echo "Starting register at [`date`]"

# Check if an elasticsearch component is being configured, and set special variables if true
if [[ ${elasticsearch_cluster[$role]} -eq 1 ]]; then
    host_file_name="${role}_${cluster_num}"
    cluster_name_file=/opt/deploy/es_clusters
    cluster_entry="${cluster_name} ${cluster_num}"
fi

ssh-keyscan -H $manager_ip >> /home/ubuntu/.ssh/known_hosts
#su - ubuntu -c "ssh  -o StrictHostKeyChecking=no ubuntu@$manager_ip" << EOF
su - ubuntu -c "ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip" << EOF
    ssh-keyscan -H $addr >> /home/ubuntu/.ssh/known_hosts

    # Build the nodes inventory
    [ ! -d "/opt/deploy/nodes" ] && sudo mkdir -p /opt/deploy/nodes && sudo chmod -R 777 /opt/deploy/nodes
    echo "address='$addr'" > /opt/deploy/nodes/${hname}

    # Build the hosts inventory
    [ ! -d "/opt/deploy/hosts" ] && sudo mkdir -p /opt/deploy/hosts && sudo chmod -R 777 /opt/deploy/hosts
    [ -f /opt/deploy/hosts/${host_file_name} ] || echo "[${role}_servers]" > /opt/deploy/hosts/${host_file_name}
    echo "$addr" >> /opt/deploy/hosts/${host_file_name}

    # Populate the elasticsearch clusters inventory if necessary
    if [[ -n "$cluster_name_file" ]]; then
        grep -Fxq "${cluster_entry}" ${cluster_name_file} || echo "${cluster_entry}" >> $cluster_name_file
    fi
    # config node when scale up
    if [ -f /opt/deploy/.POST_DEPLOY_COMPLETED ];then
        /opt/deploy/scripts/config_node.sh $role $addr --cluster-num $cluster_num --config-stack false --batch-size 100% --dependencies false
    fi
EOF
echo "End config and register at [`date`]"
