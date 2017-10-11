#!/bin/bash
#set -x
exec >> /var/log/ansible/post_deploy.log
exec 2>&1

[ $# -lt 4 ] && echo "$0 <elk_stack_name> <elk_stack_id> <kafka_topic> <kafka_shard>" && exit -1

cd `dirname $0`/../
[ ! -f "hosts/nginx_lb" ] && echo "Fail to locate the kafka nginxlb file" && exit -1

KAFKA_NGINX_SERVER=$(tail -n 1 hosts/nginx_lb)

ELASTIC_VIP=""
[ -f "/opt/deploy/vips/elasticsearch_lb" ] && ELASTIC_VIP=$(tail -n 1 /opt/deploy/vips/elasticsearch_lb)

SHARD_REGISTER_URL="https://${KAFKA_NGINX_SERVER}/es_shard"
mkdir -p shard
elk_stack_name=$1
elk_stack_id=$2
kafka_topic=$3
kafka_shard=$4

function getShardData() {
        cluster_name=$(cat es_clusters | awk '{print $1}')
        cluster_number=$(cat es_clusters | awk '{print $2}')
        weight=$(cat shard_weight)
        cluster_urls=""
        cluster_elastic_vip=${ELASTIC_VIP}
        while read -r line; do
                if [[ ${line} =~ [0-9] ]]; then
                    line=http://${line}
                    cluster_urls="${cluster_urls}\"${line}:9200\","
                fi
        done < "hosts/elasticsearch_http_${cluster_number}"
cat << EOF > shard/cluster.json
{
    "_id": "${elk_stack_id}",
    "name": "${elk_stack_name}",
    "topic": "${kafka_topic}",
    "weight": ${weight},
    "cluster": {
        "name": "${cluster_name}",
        "urls": [${cluster_urls%?}],
        "vip": "${cluster_elastic_vip}"
    },
    "kafkashard": "${kafka_shard}"
}
EOF
}

# generate bluemix token for logging@us.ibm.com and used to register shard
function getBMToken() {
	authAPI=`cat /opt/deploy/group_vars/all|grep -i BLUEMIX_AUTH_API|awk '{print $2}'`
	authUser=`cat /opt/deploy/group_vars/all|grep MONITOR_USER_ID|awk '{print $2}'`
	authCred=`cat /opt/deploy/group_vars/all|grep MONITOR_PASSWORD|awk '{print $2}'`
    tokenURL=$(echo $authAPI|sed "s/api/login/g")
    token=`curl -XPOST --silent https://$tokenURL/UAALoginServerWAR/oauth/token -H"Accept: application/json" -H"Authorization: Basic Y2Y6" -H"Content-Type: application/x-www-form-urlencoded" -d"grant_type=password&password=$authCred&scope=&username=$authUser"|jq .access_token|tr -d '"'`
    echo $token
}

bmtoken=$(getBMToken)
echo "start to register shard to ${SHARD_REGISTER_URL}"
getShardData
resp=`curl -XPOST --silent -H "Content-Type: application/json" -H "X-Auth-Token: $bmtoken" -d @shard/cluster.json "${SHARD_REGISTER_URL}" -k`
shard_id=`echo $resp|grep -i 'id'|awk '{print $3}'|cut -d "\"" -f 2`
echo "-- shard is: $shard_id, -- elk_stack_id is: $elk_stack_id"
[ "$elk_stack_id" != "$shard_id" ] && echo "Fail to register the elasticsearch shard, response is $resp" && exit -1
echo "Successfully register the elasticsearch cluster, shardid: $shard_id."
echo "$elk_stack_id" > /opt/deploy/shard/shard_id
echo "$elk_stack_name" > /opt/deploy/shard/shard_name
