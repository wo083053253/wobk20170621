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

# run as stack from the triage container
SSH_KEY="/home/stack/.ssh/id_rsa"
SSH_USER="stack"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=1200"


ES_HTTP_HOST_FILE=$(./get_cluster_host_file.sh elasticsearch_http ${CLUSTER_NUM})
[[ $? -ne 0 ]] && echo "Error getting the cluster host file for cluster elasticsearch_http ${CLUSTER_NUM}" && exit 1 
[[ ! -f "/opt/deploy/hosts/${ES_HTTP_HOST_FILE}" ]] && echo "Error finding file ${ES_HTTP_HOST_FILE}" && exit 1

ES_HTTP_HOST=$(cat /opt/deploy/hosts/${ES_HTTP_HOST_FILE} | tail -n 1)

waitToJoinCluster() {
	es=$1
	numNodes=$2
	clusterType=$3

	status=0
	while [ $status -ne $numNodes ]; do
		sleep 10
		status=$(curl ${es}:9200/_cat/nodes | grep $clusterType | wc -l)
	done
    echo "There are $numNodes nodes in the $clusterType cluster..."
}

waitForClusterHealth() {
	health=$1

    if [ "$health" == "yellow" ]; then
    	 health="\(green\|yellow\)"
    fi
    	 
	status=0
	while [ $status -ne 1 ]; do
		sleep 30
		status=$(curl ${ES_HTTP_HOST}:9200/_cluster/health?pretty | grep status | grep -e $health | wc -l)
	done
    echo  "The cluster is now $health"
}

# start the master nodes first
echo -e "\nStarting master nodes..."
ES_MASTER_HOST_FILE=$(./get_cluster_host_file.sh elasticsearch_master ${CLUSTER_NUM})
[[ $? -ne 0 ]] && echo "Error getting the cluster host file for cluster elasticsearch_master ${CLUSTER_NUM}" && exit 1 

cat /opt/deploy/hosts/${ES_MASTER_HOST_FILE} | grep \[.*\] | while read ES_HOST
do
    echo "Starting ${ES_HOST}" 
    SSH_CMD="$SSH_OPTIONS -i $SSH_KEY $SSH_USER@$ES_HOST"
    ssh $SSH_CMD sudo docker restart elasticsearch < /dev/null  
done
numMasterNodes=$(cat /opt/deploy/hosts/${ES_MASTER_HOST_FILE} | grep \[.*\] | wc -l)
echo "Number of master nodes: $numMasterNodes"

# wait for master to get elected
echo -e "\nWaiting for master to get elected..."
ES_HOST=$(cat /opt/deploy/hosts/${ES_MASTER_HOST_FILE} | tail -n 1)
waitToJoinCluster $ES_HOST $numMasterNodes master

# start the http nodes
echo -e "\nStarting http nodes..."
ES_HTTP_HOST_FILE=$(./get_cluster_host_file.sh elasticsearch_http ${CLUSTER_NUM})
[[ $? -ne 0 ]] && echo "Error getting the cluster host file for cluster elasticsearch_http ${CLUSTER_NUM}" && exit 1 

cat /opt/deploy/hosts/${ES_HTTP_HOST_FILE} | grep \[.*\] | while read ES_HOST
do
    echo "Starting ${ES_HOST}" 
    SSH_CMD="$SSH_OPTIONS -i $SSH_KEY $SSH_USER@$ES_HOST"
    ssh $SSH_CMD sudo docker restart elasticsearch < /dev/null  
done
numHttpNodes=$(cat /opt/deploy/hosts/${ES_HTTP_HOST_FILE} | grep \[.*\] | wc -l)
echo "Number of http nodes: $numHttpNodes"

# wait for http nodes to join cluster
echo -e "\nWaiting for http nodes to join the cluster"
waitToJoinCluster $ES_HTTP_HOST $numHttpNodes http

# start the data nodes
echo -e "\nStarting data nodes..."
ES_DATA_HOST_FILE=$(./get_cluster_host_file.sh elasticsearch_data ${CLUSTER_NUM})
[[ $? -ne 0 ]] && echo "Error getting the cluster host file for cluster elasticsearch_data ${CLUSTER_NUM}" && exit 1 

cat /opt/deploy/hosts/${ES_DATA_HOST_FILE} | grep \[.*\] | while read ES_HOST
do
    echo "Starting ${ES_HOST}" 
    SSH_CMD="$SSH_OPTIONS -i $SSH_KEY $SSH_USER@$ES_HOST"
    ssh $SSH_CMD sudo docker restart elasticsearch < /dev/null  
done
numDataNodes=$(cat /opt/deploy/hosts/${ES_DATA_HOST_FILE} | grep \[.*\] | wc -l)
echo "Number of data nodes: $numDataNodes"

# wait for data nodes to join cluster
echo -e "\nWaiting for data nodes to join the cluster"
waitToJoinCluster $ES_HTTP_HOST $numDataNodes data

# wait for the cluster to turn yellow
echo -e "\nWaiting for the cluster to turn yellow..."
waitForClusterHealth yellow

# enable allocation
echo -e "\nEnabling allocation..."
curl -XPUT ${ES_HTTP_HOST}:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.enable" : "all" } }'

# turn on recovery settings
echo -e "\nTurning on recovering settings..."
curl -XPUT ${ES_HTTP_HOST}:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.node_concurrent_recoveries" : "15" } }'
curl -XPUT ${ES_HTTP_HOST}:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.cluster_concurrent_rebalance" : "0" } }'

# wait for green
echo -e "\nWaiting for cluster health to turn green..."
waitForClusterHealth green

# turn off recovery settings
echo -e "\nTurning off recovery settings..."
curl -XPUT ${ES_HTTP_HOST}:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.node_concurrent_recoveries" : "2" } }'
curl -XPUT ${ES_HTTP_HOST}:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.cluster_concurrent_rebalance" : "1" } }'

echo -e "\nPost ES restart upgrade complete!"

flock -u 100
} 100<>/tmp/post_es_restart_upgrade.lock
