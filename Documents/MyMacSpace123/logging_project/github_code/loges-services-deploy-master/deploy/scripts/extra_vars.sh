#!/bin/bash
#set -x

cd `dirname $0`/../
[ $# -lt 1 ] && echo "$0 <role>" && exit -1

role=$1
cluster_num=$2

# Check if multicluster is enabled before setting vars
MULTI_CLUSTER=$(grep "MULTI_CLUSTER_ES_ENABLED" /opt/deploy/group_vars/all | awk -F ": " '{print $2}')

# Check if multi-topic is enabled before setting vars
MULTI_TOPIC=$(grep "MULTI_TOPICS_ENABLED" /opt/deploy/group_vars/all | awk -F ": " '{print $2}')

# Choose the cluster name from the proper file depending if multi cluster is enabled or not. Define global variables if multicluster is enables
if [[ "$MULTI_CLUSTER" -eq 1 ]]; then
    ES_CLUSTER_NAME=$(grep "$cluster_num" /opt/deploy/es_clusters | awk '{print $1}')
    ES_MASTER_HOSTS="elasticsearch_master_${cluster_num}"
    ES_HTTP_HOSTS="elasticsearch_http_${cluster_num}"
    ES_LB_HOSTS="elasticsearch_lb_${cluster_num}"
    DEFAULT_HTTP_HOSTS="elasticsearch_http_${cluster_num}"
else
    if [ -e "/opt/deploy/hosts/elasticsearch_http_1" ]; then
       ES_CLUSTER_NAME="elasticsearch_1"
       ES_MASTER_HOSTS="elasticsearch_master_1"
       ES_HTTP_HOSTS="elasticsearch_http_1"
       ES_LB_HOSTS="elasticsearch_lb_1"
       DEFAULT_HTTP_HOSTS="elasticsearch_http_1"
    else
       ES_CLUSTER_NAME="elasticsearch"
       ES_MASTER_HOSTS="elasticsearch_master"
       ES_HTTP_HOSTS="elasticsearch_http"
       ES_LB_HOSTS="elasticsearch_lb"
       DEFAULT_HTTP_HOSTS="elasticsearch_http"
    fi
fi

export TENANTINFO_LB_IP="$(tail -n +2 hosts/multiserver_lb)"
export NGINX_LB_IP="$(tail -n +2 hosts/nginx_lb)"
export MTLUMBERJACK_LB_IP="$(tail -n +2 hosts/mtlumberjack_lb)"

function internalMonitorVars()
{
    enable_sidecar=`cat group_vars/all | grep -c sidecar_target_logs`
    metrics_target=`cat group_vars/all | grep -i sidecar_target_metrics | awk '{print $2;}'`
    echo "metrics_target=${metrics_target}"
    if [[ "${enable_sidecar}" == "1" || -n "${metrics_target}" ]]; then
        org=`cat group_vars/all | grep -i sidecar_target_tenant_org | awk '{print $2;}'`
        space=`cat group_vars/all | grep -i sidecar_target_tenant_space | awk '{print $2;}'`
        logmet_api=`cat group_vars/all | grep -i sidecar_target_api | awk '{print $2;}'`

        monitorUser=`cat group_vars/all | grep MONITOR_USER_ID | awk '{print $2;}'`
        monitorUserPwd=`cat group_vars/all | grep MONITOR_PASSWORD | awk '{print $2;}'`

        token=`cat group_vars/all | grep sidecar_target_token | awk '{print $2;}'`
        spaceid=`cat group_vars/all | grep sidecar_target_space_id | awk '{print $2;}'`

        if [ "$token" == "" ] || [ "$spaceid" == "" ]; then
            result=`curl -s -k -XPOST -d"user=${monitorUser}&passwd=${monitorUserPwd}&space=${space}&org=${org}" https://${logmet_api}/login`

            if [ $? -eq 0 ]; then
                token=`echo "$result" | grep "logging_token" | awk '{print $2;}' | tr -d '",'`
                spaceid=`echo "$result" | grep "space_id" | awk '{print $2;}' | tr -d '",'`
            else
                token="lookup_failed"
                spaceid="lookup_failed"
            fi
        fi
        echo "sidecar_target_token=${token}"
        echo "sidecar_target_spaceid=${spaceid}"
        echo "metrics_target_token=${token}"
        echo "metrics_target_spaceid=${spaceid}"
    else
        echo "sidecar_target_spaceid="
        echo "metrics_target_token="
        echo "metrics_target_spaceid="
    fi
}

function get_es_log_clusters()
{
    port=$1
    clusters=""
    while read es_cluster_definition; do
        es_cluster_name=$(echo ${es_cluster_definition} | awk '{print $1}')
        es_cluster_number=$(echo ${es_cluster_definition} | awk '{print $2}')
        cluster_def="${es_cluster_name}:"
        while read ip_address; do
            if [[ $ip_address =~ [0-9] ]]; then
                if [ -z "$port" ]; then
                    cluster_def="${cluster_def}${ip_address},"
                else
                    cluster_def="${cluster_def}${ip_address}:${port},"
                fi
            fi
        done < /opt/deploy/hosts/elasticsearch_http_${es_cluster_number}

        clusters+="${cluster_def%?};"
    done < /opt/deploy/es_clusters

    echo "${clusters%?}"
}

function elasticsearch_master()
{
    elasticsearch
}

function elasticsearch_data_hot()
{
    elasticsearch
}

function elasticsearch_data_warm()
{
    elasticsearch
}

function elasticsearch_http()
{
    elasticsearch
}

function elasticsearch()
{
    elastic_search_list=''

    for i in $(tail -n +2 hosts/${ES_MASTER_HOSTS}); do
        elastic_search_list="$elastic_search_list,$i"
    done

    if [[ "$MULTI_CLUSTER" -eq 1 ]]; then
      logstash_group="logstash_${cluster_num}"
    else
      logstash_group="logstash"
    fi

    echo "MASTER_CANDIDATES_NAME=${elastic_search_list/,/}
        ES_CLUSTER_NAME=${ES_CLUSTER_NAME} LOGSTASH_GROUP=${logstash_group}"
}

function elasticsearch_lb()
{
    ELASTICSEARCH_PORT=9200
    ELASTICSEARCH_HTTP_SERVERS=''
    flag=0
    for ip in $(tail -n +2 hosts/${ES_HTTP_HOSTS}); do
        hostname=$(grep -l $ip nodes/*)
        hostname=${hostname##*/}
        if [ $flag -eq 0 ]; then
            flag=1
        else
            ELASTICSEARCH_HTTP_SERVERS+=", "
        fi
        ELASTICSEARCH_HTTP_SERVERS+="{\"name\":\""$hostname"\",\"address\":\""$ip"\"}"
    done

    ELASTICSEARCH_VIP_ADDRESS="$(cat vips/elasticsearch_lb)"
    ELASTICSEARCH_VROUTER_ID=$(echo $ELASTICSEARCH_VIP_ADDRESS | awk -F '.' '{print $4}')
    echo "{\"ELASTICSEARCH_BACKEND_SERVERS\": [$ELASTICSEARCH_HTTP_SERVERS], \"VIP_ADDRESS\":\"$ELASTICSEARCH_VIP_ADDRESS\", \"VROUTER_ID\":\"$ELASTICSEARCH_VROUTER_ID\"}"
}

function logstash()
{
    zookeeper_servers=''
    kafka_servers=''
    elastic_search_list=''
    elastic_search_http_list=''

    kafka_topic="$(cat /opt/deploy/kafka_topic)"
    cluster_name="$(cat /opt/deploy/es_clusters | awk '{print $1}')"

    if [ -z "$kafka_topic" ]; then
        echo "Fail to find the kafka topic"
        exit -1
    fi

    for i in $(tail -n +2 hosts/kafka); do
        if [ -z "$kafka_servers" ]; then
            kafka_servers="\"$i:9092\""
        else
            kafka_servers="$kafka_servers,""\"$i:9092\""
        fi
    done

    for i in $(tail -n +2 hosts/zookeeper); do
        zookeeper_servers="$zookeeper_servers,""$i:2181"
    done

    for i in $(tail -n +2 hosts/${ES_MASTER_HOSTS}); do
        elastic_search_list="$elastic_search_list","\"$i\""
    done

    for i in $(tail -n +2 hosts/${ES_HTTP_HOSTS}); do
        elastic_search_port_http_list="$elastic_search_port_http_list","\"$i:9200\""
    done

    elastic_search_http_list="$(cat vips/elasticsearch_lb)"

    esalias_enable_date=`grep ESALIAS_ENABLE_DATE group_vars/all | awk '{ print $2 }'`

    elkshardidprefix=$(cat /opt/deploy/shard_id|cut -d"-" -f 1)
    if [[ "$MULTI_CLUSTER" -eq 1 ]]; then
      consumer_group_id="logstash_${elkshardidprefix}_${cluster_num}"
    else
      if [ -e "hosts/elasticsearch_http_1" ]; then
         consumer_group_id="logstash_1"
      else
         consumer_group_id="logstash"
      fi
    fi

    echo "KAFKA_TOPIC='${kafka_topic}-${cluster_name}'
        KAFKA_SERVERS='${kafka_servers}'
        consumer_group_id='${consumer_group_id}'
        ES_CLUSTER_NAME='${ES_CLUSTER_NAME}'
        TENANTINFO_IP='${TENANTINFO_LB_IP}'
        TENANTINFO_PORT=9099
        zookeeper_servers='${zookeeper_servers/,/}'
        ELASTICSEARCH_HTTP_NODE_LOGSTASH='${elastic_search_http_list/,/}'
        ELASTICSEARCH_HTTP_LIST='${elastic_search_port_http_list/,/}'
        MASTER_CANDIDATES_LOGSTASH='${elastic_search_list/,/}'
        carbon_relay='${CARBONRELAY_LB_IP}'
        ESALIAS_ENABLE_DATE='${esalias_enable_date}'"
}

function logstash_fastforwarder()
{
    zookeeper_servers=''
    elastic_search_list=''
    elastic_search_http_list=''
    topic_id='alchemy-logs-ff'
    for i in $(tail -n +2 hosts/zookeeper); do
        zookeeper_servers="$zookeeper_servers,""$i:2181"
    done

    for i in $(tail -n +2 hosts/${ES_MASTER_HOSTS}); do
        elastic_search_list="$elastic_search_list","\"$i\""
    done

    for i in $(tail -n +2 hosts/${ES_HTTP_HOSTS}); do
        elastic_search_http_list="$elastic_search_http_list","\"$i\""
        elastic_search_port_http_list="$elastic_search_port_http_list","\"$i:9200\""
    done

    esalias_enable_date=`grep ESALIAS_ENABLE_DATE group_vars/all | awk '{ print $2 }'`

    consumer_group_id="logstash_ff_grp"

    echo "consumer_group_id='${consumer_group_id}'
        topic_id='${topic_id}'
        ES_CLUSTER_NAME='${ES_CLUSTER_NAME}'
        TENANTINFO_IP='${TENANTINFO_LB_IP}'
        TENANTINFO_PORT=9099
        zookeeper_servers='${zookeeper_servers/,/}'
        ELASTICSEARCH_HTTP_NODE_LOGSTASH='${elastic_search_http_list/,/}'
        ELASTICSEARCH_HTTP_LIST='${elastic_search_port_http_list/,/}'
        MASTER_CANDIDATES_LOGSTASH='${elastic_search_list/,/}'
        carbon_relay='${CARBONRELAY_LB_IP}'
        ESALIAS_ENABLE_DATE='${esalias_enable_date}'"
}

function logstash_objstore()
{
    zookeeper_servers=''
    elastic_search_list=''
    elastic_search_http_list=''

    kafka_topic="$(cat /opt/deploy/kafka_topic)"
    cluster_name="$(cat /opt/deploy/es_clusters | awk '{print $1}')"
    if [ -z "$kafka_topic" ]; then
        echo "Fail to find the kafka topic"
        exit -1
    fi

    TENANTINFO_SERVER="$(tail -n +2 /opt/deploy/hosts/multiserver_lb)"
    if [ -z "$TENANTINFO_SERVER" ]; then
        echo "Fail to find the tenantinfo server"
        exit -1
    fi

    for i in $(tail -n +2 hosts/${ES_MASTER_HOSTS}); do
        elastic_search_list="$elastic_search_list","\"$i\""
    done

    for i in $(tail -n +2 hosts/${ES_HTTP_HOSTS}); do
        elastic_search_http_list="$elastic_search_http_list","\"$i\""
        elastic_search_port_http_list="$elastic_search_port_http_list","\"$i:9200\""
    done

    for i in $(tail -n +2 hosts/zookeeper); do
        zookeeper_servers="$zookeeper_servers,""$i:2181"
    done

    kafka_servers=''
    for i in $(tail -n +2 hosts/kafka); do
        if [ -z "$kafka_servers" ]; then
            kafka_servers="$i:9092"
        else
            kafka_servers="$kafka_servers,$i:9092"
        fi
    done

    # set objstore cluster name
    if ! grep 'objstore_cluster_name' group_vars/logstash_objstore_servers ;then
        suffix=$(openssl rand -hex 4)
        echo "objstore_cluster_name: objstore-${suffix}" >> group_vars/logstash_objstore_servers
    fi
    objstore_cluster_name=$(grep objstore_cluster_name group_vars/logstash_objstore_servers | awk '{print $2}')

    swift_restore_topic="swift-restore-$kafka_topic-$cluster_name"
    swift_restore_progress_topic="swift-restore-progress-$kafka_topic-$cluster_name"

    esalias_enable_date=`grep ESALIAS_ENABLE_DATE group_vars/all | awk '{ print $2 }'`

    echo "KAFKA_TOPIC='${kafka_topic}-${cluster_name}'
        KAFKA_SERVERS='${kafka_servers}'
        TENANTINFO_IP='${TENANTINFO_LB_IP}'
        TENANTINFO_PORT=9099
        swift_restore_topic='${swift_restore_topic}'
        swift_restore_progress_topic='${swift_restore_progress_topic}'
        ES_CLUSTER_NAME='${ES_CLUSTER_NAME}'
        space_mapping_url='https://${TENANTINFO_SERVER}:9099/swiftproject'
        account_mapping_url='https://${TENANTINFO_SERVER}:9099/space_account'
        kafka_servers='${kafka_servers}'
        client_auth=$(cat client_auth)
        zookeeper_servers=${zookeeper_servers/,/}
        ELASTICSEARCH_HTTP_NODE_LOGSTASH='${elastic_search_port_http_list/,/}'
        MASTER_CANDIDATES_LOGSTASH='${elastic_search_list/,/}'
        objstore_cluster_name=${objstore_cluster_name}
        carbon_relay='${CARBONRELAY_LB_IP}'
        ESALIAS_ENABLE_DATE='${esalias_enable_date}'"
}

function logstash_recentdata()
{
    zookeeper_servers=''
    elastic_search_list=''
    elastic_search_http_list=''

    kafka_topic="$(cat /opt/deploy/kafka_topic)"
    cluster_name="$(cat /opt/deploy/es_clusters | awk '{print $1}')"
    if [ -z "$kafka_topic" ]; then
        echo "Fail to find the kafka topic"
        exit -1
    fi

    TENANTINFO_SERVER="$(tail -n +2 /opt/deploy/hosts/multiserver_lb)"
    if [ -z "$TENANTINFO_SERVER" ]; then
        echo "Fail to find the tenantinfo server"
        exit -1
    fi

    for i in $(tail -n +2 hosts/${ES_MASTER_HOSTS}); do
        elastic_search_list="$elastic_search_list","\"$i\""
    done

    for i in $(tail -n +2 hosts/${ES_HTTP_HOSTS}); do
        elastic_search_http_list="$elastic_search_http_list","\"$i\""
        elastic_search_port_http_list="$elastic_search_port_http_list","\"$i:9200\""
    done

    for i in $(tail -n +2 hosts/zookeeper); do
        zookeeper_servers="$zookeeper_servers,""$i:2181"
    done

    kafka_servers=''
    for i in $(tail -n +2 hosts/kafka); do
        if [ -z "$kafka_servers" ]; then
            kafka_servers="$i:9092"
        else
            kafka_servers="$kafka_servers,$i:9092"
        fi
    done

    # set objstore cluster name
    if ! grep 'objstore_cluster_name' group_vars/logstash_recentdata_servers ;then
        suffix=$(openssl rand -hex 4)
        echo "objstore_cluster_name: objstore-${suffix}" >> group_vars/logstash_recentdata_servers
    fi
    objstore_cluster_name=$(grep objstore_cluster_name group_vars/logstash_recentdata_servers | awk '{print $2}')

    swift_restore_topic="swift-restore-$kafka_topic-$cluster_name"
    swift_restore_progress_topic="swift-restore-progress-$kafka_topic-$cluster_name"

    esalias_enable_date=`grep ESALIAS_ENABLE_DATE group_vars/all | awk '{ print $2 }'`

    echo "KAFKA_TOPIC='${kafka_topic}-${cluster_name}'
        KAFKA_SERVERS='${kafka_servers}'
        swift_restore_topic='${swift_restore_topic}'
        swift_restore_progress_topic='${swift_restore_progress_topic}'
        ES_CLUSTER_NAME='${ES_CLUSTER_NAME}'
        space_mapping_url='https://${TENANTINFO_SERVER}:9099/swiftproject'
        account_mapping_url='https://${TENANTINFO_SERVER}:9099/space_account'
        kafka_servers='${kafka_servers}'
        client_auth=$(cat client_auth)
        zookeeper_servers=${zookeeper_servers/,/}
        ELASTICSEARCH_HTTP_NODE_LOGSTASH='${elastic_search_port_http_list/,/}'
        ELASTICSEARCH_HTTP_LIST='${elastic_search_port_http_list/,/}'
        MASTER_CANDIDATES_LOGSTASH='${elastic_search_list/,/}'
        TENANTINFO_IP='${TENANTINFO_LB_IP}'
        TENANTINFO_PORT=9099
        objstore_cluster_name=${objstore_cluster_name}
        carbon_relay='${CARBONRELAY_LB_IP}'
        ESALIAS_ENABLE_DATE='${esalias_enable_date}'"
}

function log_splitter()
{
    zookeeper_servers=''
    for i in $(tail -n +2 hosts/zookeeper); do
        zookeeper_servers="$zookeeper_servers,""$i:2181"
    done

    echo "zookeeper_servers=${zookeeper_servers/,/}"
}

function monitor()
{
    MULTI_CLUSTER_ES_ENABLED=`cat group_vars/all | grep -i MULTI_CLUSTER_ES_ENABLED | awk '{print $2;}'`
    if [ $MULTI_CLUSTER_ES_ENABLED -eq 0 ]; then
        es_clusters_to_monitor=1
    else
        es_clusters_to_monitor=`cat group_vars/monitor_servers | grep -i ES_CLUSTERS_TO_MONITOR | awk '{print $2;}'`
        if [ $es_clusters_to_monitor == "ALL" ]; then
            count=1
            for es_master in $(ls hosts/elasticsearch_master_*); do
                index=`echo $es_master | sed -r 's/hosts\/elasticsearch_master_//'`
                if [ $count -eq 1 ]; then
                    es_clusters_to_monitor=$index
                else
                    es_clusters_to_monitor=${es_clusters_to_monitor},$index
                fi
                count=$[${count}+1]
            done
        fi
    fi

    echo "ES_CLUSTERS_TO_MONITOR=${es_clusters_to_monitor}"

    if [ -z $TENANTINFO_LB_IP ]; then
        echo "TENANTINFO_LB_IP="
    else
        echo "TENANTINFO_LB_IP=${TENANTINFO_LB_IP}"
    fi

    host_name=`cat group_vars/all | grep "dashboard_proxy" | awk '{print $2;}'`
    host_ip=`nslookup $host_name | awk 'NR==6 {print $2}'`
    nginx_floating_ip="$NGINX_LB_IP"
    if [ "$host_ip" == "$nginx_floating_ip" ]
    then
        echo "IP_OVERRIDE_LOGS="
        echo "IP_OVERRIDE_METRICS="
        echo "IP_OVERRIDE_API="
    else
        echo "IP_OVERRIDE_LOGS=$MTLUMBERJACK_LB_IP"
        echo "IP_OVERRIDE_METRICS=$MTGRAPHITE_LB_IP"
        echo "IP_OVERRIDE_API=$NGINX_LB_IP"
    fi

    echo "graphite_floating_lb='${GRAPHITEWEB_LB_IP}'"

    if [ -z "${KAFKA_LAG_LOGS_DOWN_THRESHOLD}" ]; then
        KAFKA_LAG_LOGS_DOWN_THRESHOLD=50000000
        echo "KAFKA_LAG_LOGS_DOWN_THRESHOLD=50000000"
    fi
    if [ -z "${KAFKA_LAG_METRICS_DOWN_THRESHOLD}" ]; then
        KAFKA_LAG_METRICS_DOWN_THRESHOLD=50000000
        echo "KAFKA_LAG_METRICS_DOWN_THRESHOLD=50000000"
    fi

}

function manager()
{
    if [ -e "/opt/deploy/hosts/dashboard_es" ]; then
       dashboard_es_http=$(tail -n 1 hosts/dashboard_es)
    else
       dashboard_es_http=$(tail -n 1 hosts/${ES_HTTP_HOSTS})
    fi
    dashboard_space_id=$(grep "graphite_environment:" /opt/deploy/group_vars/all | awk '{print $2}' | awk -F . '{print $1}')
    dashboard_env=$(grep "graphite_environment:" /opt/deploy/group_vars/all | awk '{print $2}' | awk -F . '{print $2}')

    if [ -e /opt/deploy/files/conductors-map.json ]; then
        conductor_space_id=$(jq --raw-output .conductor_space /opt/deploy/files/conductors-map.json)
        conductor_env=$(jq --raw-output .location /opt/deploy/files/conductors-map.json )
        conductor_options="\"--conductor-spaceid ${conductor_space_id} --conductor-env ${conductor_env}\""
    else
        conductor_options=""
    fi

    # Choose the cluster name from the proper file depending if multi cluster is enabled or not. Define global variables if multicluster is enables
    kafka_log_topics="alchemy-logs"
    if [[ "$MULTI_TOPIC" -eq 1 && -e /opt/deploy/es_clusters ]]; then
        kafka_log_topics=""
        while read es_cluster_definition; do
            cluster_name=$(echo $es_cluster_definition | awk '{print $1}')
            kafka_log_topics+=",alchemy-logs-$cluster_name"
        done < /opt/deploy/es_clusters
    fi

    tenantinfo_lb_ip="https://$(tail -n -1 hosts/multiserver_lb):9099"
    alogmon_lb_ip="http://$(tail -n -1 hosts/multiserver_lb):8777"
    elasticsearch_vip="http://$(tail -n -1 vips/elasticsearch_lb):9200"
    hot_node_num=`ls /opt/deploy/nodes/ | grep data_hot | wc -l`
    logging_env=`cat /opt/deploy/group_vars/all | grep STACK_NAME | awk '{print $2}'`

    echo "CLUSTER_NUM=$cluster_num LOGGING_ENV=$logging_env HOT_NODE_NUM=$hot_node_num ALOGMON_URL=${alogmon_lb_ip} TENANTINFO_URL=${tenantinfo_lb_ip} ELASTICSEARCH_URL=${elasticsearch_vip} dashboard_es_http=${dashboard_es_http}:9200 dashboard_space_id=${dashboard_space_id} dashboard_env=${dashboard_env} conductor_options=${conductor_options} kafka_log_topics=${kafka_log_topics/,/}"
}

function recursivehost()
{
    role=$1
    $role
    for r in `grep 'include' ${role}.yml | cut -d: -f2 | cut -d. -f1`; do
        recursivehost $r
    done
}

if [ "$role" = "elasticsearch_lb" ]; then
    elasticsearch_lb
else
    recursivehost $role

    if [ -z "${batch_size}"]; then
        batch_size=100%
    fi
    evars="rolling_update_batch_size=${batch_size}"


    $role
    for r in `ansible-playbook -i hosts/.all ${role}.yml --list-hosts --extra-vars="${evars}"  | grep 'servers)' | cut -d'(' -f2 | sed 's/_servers).*//g' | sort -u`; do
        $r
    done

    #Get the sidecar metata for all server types
    if [[ "$role" != "eventgen_rest" ]]; then
        internalMonitorVars
    fi
fi

