#!/bin/sh

[[ $# -eq 0 || $# -gt 3 ]] && echo "Usage: $0 <role> --cluster-num <clusterNum>" && exit 1

ROLE=$1
shift

for i in "$@"; do # Parse the remaining command line arguments in the standard fashion
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

CONTAINER_NAME="elasticsearch"

ES_HOST=$(./get_cluster_host_file.sh ${ROLE} ${CLUSTER_NUM})
[[ $? -ne 0 ]] && echo "Error getting the cluster host file for cluster ${ROLE} ${CLUSTER_NUM}" && exit 1 
[[ ! -f "/opt/deploy/hosts/${ES_HOST}" ]] && echo "Error finding file ${ES_HOST}" && exit 1

cat /opt/deploy/hosts/${ES_HOST} | grep \[.*\] | while read HOST
do
        echo $HOST
        #ssh $HOST "sudo docker ps" < /dev/null
        ssh $HOST "sudo docker exec ${CONTAINER_NAME} cat /etc/elasticsearch/elasticsearch.yml | grep  rack " < /dev/null
done
