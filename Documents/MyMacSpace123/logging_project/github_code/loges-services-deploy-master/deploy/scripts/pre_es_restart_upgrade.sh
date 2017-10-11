#!/bin/bash
#set -x

[ $# -gt 2 ] && echo "Usage: $0 --cluster-num <clusterNum>" && exit 1


{

trap 'echo The same script is currently running. Exit.' ERR
flock -n 100
trap - ERR   # reset ERR trap

# Parse the command line arguments
for i in "$@"; do 
     opt="$1"
     shift
     case "$opt" in
        -n | --cluster-num)
            CLUSTER_NUM="$1"
            shift
            ;;
        '')
            break
            ;;
        *)
            echo "Incorrect argument format or unknown option \"$i\""
            exit 1
            ;;
    esac
done


stop_cluster() {
	local role=$1

	# run as stack from the triage container
	local ssh_key="/home/stack/.ssh/id_rsa"
	local ssh_user="stack"
	local ssh_options="-o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=1200"

	echo -e "\nStopping $1 nodes..."
	local cluster_host_file=$(./get_cluster_host_file.sh $role $CLUSTER_NUM)
	[[ $? -ne 0 ]] && echo "Error getting the cluster host file for cluster elasticsearch_http ${CLUSTER_NUM}" && exit 1 

	cat /opt/deploy/hosts/${cluster_host_file} | grep \[.*\] | while read es_host
	do
	    echo "Stopping ${es_host}" 
	    ssh_cmd="$ssh_options -i $ssh_key $ssh_user@$es_host"
	    ssh $ssh_cmd sudo docker stop elasticsearch < /dev/null  
	done
}

ES_HTTP_HOST=$(./get_cluster_host_file.sh elasticsearch_http ${CLUSTER_NUM})
[[ $? -ne 0 ]] && echo "Error getting the cluster host file for cluster elasticsearch_http ${CLUSTER_NUM}" && exit 1 

ES_HOST=$(cat /opt/deploy/hosts/${ES_HTTP_HOST} | tail -n 1)
echo "Starting preparation for ES cluster restart upgrade..."

# disable shard allocation
echo -e "\nDisabling shard allocation..."
curl -XPUT ${ES_HOST}:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.enable" : "none" } }'

# perform a sync flush
echo -e "\nPerforming synch flush..."
curl -XPOST  ${ES_HOST}:9200/_flush/synced

# shutdown the cluster
echo -e "\nShutting down the cluster..."
stop_cluster elasticsearch_master
stop_cluster elasticsearch_http
stop_cluster elasticsearch_data

echo -e "\nPre ES restart upgrade complete!"

flock -u 100
} 100<>/tmp/pre_es_restart_upgrade.lock
