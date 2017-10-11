#!/bin/sh

[ $# -gt 2 ] && echo "Usage: $0 --cluster-num <clusterNum>" && exit 1

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

elastic_http="$(cat /opt/deploy/hosts/${ES_HTTP_HOST} | tail -n 1):9200"

echo curl -s "${elastic_http}/_cluster/health?pretty"
curl -s "${elastic_http}/_cluster/health?pretty" < /dev/null

echo curl -s "${elastic_http}/_cluster/settings?pretty"
curl -s "${elastic_http}/_cluster/settings?pretty" < /dev/null

echo "curl -s \"${elastic_http}/_cat/nodes?v&pretty\" | sort -rk3"

nodes=`curl -s "${elastic_http}/_cat/nodes?v&pretty" | sort -rk3`  </dev/null
echo "$nodes"

echo "curl -s ${elastic_http}/_cat/allocation?v&pretty | grep data | sort -rnk1"
allocation=`curl -s "${elastic_http}/_cat/allocation?v&pretty" | grep data | sort -rnk1` < /dev/null
echo "$allocation"

echo curl -s "${elastic_http}/_cat/thread_pool?v"
curl -s "${elastic_http}/_cat/thread_pool?v" < /dev/null

echo curl -s "${elastic_http}/_cat/recovery?active_only=true "
curl -s "${elastic_http}/_cat/recovery?active_only=true"  < /dev/null

echo "curl -s ${elastic_http}/_cat/shards?pretty | grep RELO"
relocated=`curl -s "${elastic_http}/_cat/shards?pretty" | grep RELO` < /dev/null
echo "$relocated"

echo "curl -s ${elastic_http}/_cat/shards?pretty | grep INIT"
init=`curl -s "${elastic_http}/_cat/shards?pretty" | grep INIT` < /dev/null
echo "$init"

echo "curl -s ${elastic_http}/_cat/shards?pretty | grep UNASSIGNED"
curl -s "${elastic_http}/_cat/shards?pretty" | grep UNASSIGNED
echo "-------------------------------------------------------------------------"
