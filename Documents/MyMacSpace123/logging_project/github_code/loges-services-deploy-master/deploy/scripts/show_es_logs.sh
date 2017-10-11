#!/bin/sh

[[ $# -eq 0 || $# -gt 3 ]] && echo "Usage: $0 <role> | master_only --cluster-num <clusterNum>" && exit 1

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
if [[ "${ROLE}" == "master_only" ]]; then

        ES_HTTP_HOST=$(./get_cluster_host_file.sh elasticsearch_http ${CLUSTER_NUM})
        [[ $? -ne 0 ]] && echo "Error getting the cluster host file for cluster ${ROLE} ${CLUSTER_NUM}" && exit 1 
        [[ ! -f "/opt/deploy/hosts/${ES_HTTP_HOST}" ]] && echo "Error finding file ${ES_HTTP_HOST}" && exit 1

        ES_HTTP_IP=`tail -n 1 /opt/deploy/hosts/${ES_HTTP_HOST}`
        ES_MASTER=`curl -s -XGET ${ES_HTTP_IP}:9200/_cat/master?h=n`

        MASTER_IP=`cat /opt/deploy/nodes/${ES_MASTER} | grep "addres" | cut -d"'" -f2`
        echo $MASTER_IP $ES_MASTER
        ssh $MASTER_IP "sudo docker exec ${CONTAINER_NAME} tail -100 /var/log/elasticsearch/elasticsearch.log" < /dev/null
else
        ES_HOST=$(./get_cluster_host_file.sh ${ROLE} ${CLUSTER_NUM})
        [[ $? -ne 0 ]] && echo "Error getting the cluster host file for cluster ${ROLE} ${CLUSTER_NUM}" && exit 1 
        [[ ! -f "/opt/deploy/hosts/${ES_HOST}" ]] && echo "Error finding file ${ES_HOST}" && exit 1

        if [ -z "$CLUSTER_NUM" ]; then
                LOG_FILE="elasticsearch.log"                
        else
                LOG_FILE="elasticsearch_${CLUSTER_NUM}.log"                
        fi                

        [[ $? -ne 0 ]] && echo "Error getting the logfile name for cluster ${CLUSTER_NUM}" && exit 1 

        cat /opt/deploy/hosts/${ES_HOST} | grep \[.*\] | while read HOST
        do
                hn=`ssh $HOST hostname </dev/null`
                echo $HOST $hn
                ssh $HOST "sudo docker exec ${CONTAINER_NAME} tail -60 /var/log/elasticsearch/${LOG_FILE}" < /dev/null
                echo -e "-----------------------------------\n\n"
        done
fi
