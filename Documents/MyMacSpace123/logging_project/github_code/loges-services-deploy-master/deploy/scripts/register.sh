#!/bin/bash

cd `dirname $0`/../
[ $# -lt 3 ] && echo "$0 <role> <hostname> <ip_address> <restart_url> <cluster_number>" && exit -1

role=$1
hname=$2
addr=$3
rurl=$4
cluster_num=$5

declare -A multicluster=([elasticsearch_master]=1 [elasticsearch_http]=1 [elasticsearch_lb]=1 [elasticsearch_data_hot]=1 [elasticsearch_data_warm]=1 [logstash]=1 [logstash_fastforwarder]=1 [logstash_objstore]=1)

{
    flock 100
    logger "manager_register.sh $role $hname $addr Starting"

    # Check if multi_cluster is enabled
    MULTI_CLUSTER_ENABLED=$(grep "MULTI_CLUSTER_ES_ENABLED" /opt/deploy/group_vars/all | awk -F ": " '{print $2}')

    # Function to check if the role being configured is part of the Elasticsearch cluster and set the host_file_name accordingly.
    # Fail if cluster_num is not defined
    function get_host_file_name() {
        local role=$1
        local host_file_name=$role
        if [[ "$MULTI_CLUSTER_ENABLED" -eq 1 ]]; then
            if [[ ${multicluster[$role]} ]]; then
                if [ -z "$cluster_num" ]; then
                    echo "WARNING: the \"--cluster-num\" argument must be defined when \"$role\" is being configured."
                    exit 1
                fi
                host_file_name=${role}_${cluster_num}
            fi
        fi
        echo "$host_file_name"
    }

    # Set the global host file name for the role
    host_file_name=$(get_host_file_name $role)
    [ -f hosts/"${host_file_name}" ] || exit 1

    [ -f nodes/$hname ] ||
        ( echo "address='$addr'"
          echo "restart_url='$rurl'") > nodes/$hname
    [ -f hosts/${host_file_name} ] || echo "[${host_file_name}_servers]" > hosts/${host_file_name}
    grep -q $addr hosts/${host_file_name} ||
        echo $addr >> hosts/${host_file_name}
    cat hosts/* > hosts/.all
    evars=""
    if [ -f scripts/extra_vars.sh ]; then
        evars=$(scripts/extra_vars.sh $role $cluster_num)
    fi

    if [ ! -f /var/log/ansible/playbook.log ]; then
        sudo mkdir -p /var/log/ansible
        sudo chown stack:stack /var/log/ansible
    fi

    host_key=$(ssh-keyscan -t rsa "$address")
    echo $host_key >> ~/.ssh/known_hosts

    date >> /var/log/ansible/playbook.log
    ansible-playbook -vvv -i hosts/.all cflogin.yml --extra-vars="cf_auth_refresh_interval=360" >> /var/log/ansible/playbook.log
    ansible-playbook -vvv -i hosts/${host_file_name} cfConfigCopy.yml  --extra-vars="cluster=${role} cf_auth_refresh_interval=360">> /var/log/ansible/playbook.log
    ansible-playbook -vvv -i hosts/.all ${role}.yml --extra-vars="$evars" --extra-vars="rolling_update_batch_size=1 es_change_type=es_update" >> /var/log/ansible/playbook.log
    logger "manager_register.sh $role Ending"
    flock -u 100
} 100<>/tmp/register.lock
