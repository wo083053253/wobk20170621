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

ES_HTTP_HOST=$(./get_cluster_host_file.sh elasticsearch_http ${CLUSTER_NUM})
[[ $? -ne 0 ]] && echo "Error getting the cluster host file for cluster elasticsearch_http ${CLUSTER_NUM}" && exit 1 
[[ ! -f "/opt/deploy/hosts/${ES_HTTP_HOST}" ]] && echo "Error finding file ${ES_HTTP_HOST}" && exit 1

ES_HOST=$(cat /opt/deploy/hosts/${ES_HTTP_HOST} | tail -n 1)

# turn on recovery settings
echo "Turning on recovering settings..."
curl -XPUT ${ES_HOST}:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.node_concurrent_recoveries" : "15" } }'
curl -XPUT ${ES_HOST}:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.cluster_concurrent_rebalance" : "0" } }'

# wait for green
echo "Waiting for cluster health to turn green..."
status=0
while [ $status -ne 1 ]; do
	sleep 30
	status=$(curl ${ES_HOST}:9200/_cluster/health?pretty | grep status | grep green | wc -l)
done

# turn off recovery settings
echo "Turning off recovery settings..."
curl -XPUT ${ES_HOST}:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.node_concurrent_recoveries" : "2" } }'
curl -XPUT ${ES_HOST}:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.cluster_concurrent_rebalance" : "1" } }'

echo "Post ES rolling upgrade complete!"

flock -u 100
} 100<>/tmp/post_es_rolling_upgrade.lock

