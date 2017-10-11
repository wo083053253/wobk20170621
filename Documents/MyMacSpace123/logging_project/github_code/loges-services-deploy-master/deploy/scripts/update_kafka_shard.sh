#!/bin/bash
#set -x
exec >> /var/log/ansible/post_deploy.log
exec 2>&1

[ $# -lt 1 ] && echo "$0 <kafkashardid>" && exit -1

cd `dirname $0`/../
[ ! -f "hosts/nginx_lb" ] && echo "Fail to locate the nginx_lb host file" && exit -1
[ ! -f "/opt/deploy/shard/shard_id" ] && echo "Fail to find the elasticsearch shard id file" && exit -1

kafkashardid=$1
KAFKA_NGINX_SERVER=$(tail -n 1 hosts/nginx_lb)
SHARD_REGISTER_URL="https://${KAFKA_NGINX_SERVER}/kafka_shard/$kafkashardid"
mkdir -p kafkashard
ELASTIC_VIP=""
[ -f "/opt/deploy/vips/elasticsearch_lb" ] && ELASTIC_VIP=$(tail -n 1 /opt/deploy/vips/elasticsearch_lb)

function getKafkaShardData() {
    kafka_topic="$(cat /opt/deploy/kafka_topic)"
    cluster_name="$(cat /opt/deploy/es_clusters | awk '{print $1}')"
    partitions="$(cat /opt/deploy/group_vars/kafka_topics |grep -i NUMBER_OF_LOG_PARTITIONS|awk '{print $2}')"
    replica="$(cat /opt/deploy/group_vars/kafka_topics |grep -i LOG_REPLICATION_FACTOR|awk '{print $2}')"
    elkshardid="$(cat /opt/deploy/shard/shard_id)"
    elkshardname="$(cat /opt/deploy/shard/shard_name)"
cat << EOF > kafkashard/cluster.json
{
  "kafkatopics": [
	{
      "name": "$kafka_topic-$cluster_name",
      "partitions": $partitions,
      "replica": $replica
    },
    {
      "name": "swift-restore-$kafka_topic-$cluster_name",
      "partitions": $partitions,
      "replica": $replica
    },
    {
      "name": "swift-restore-progress-$kafka_topic-$cluster_name",
      "partitions": $partitions,
      "replica": $replica
    }
  ],
  "esshards": [
  	{
      "id": "$elkshardid",
      "shardname": "$elkshardname",
      "clustername": "$cluster_name",
      "topic": "$kafka_topic",
      "esvip": "$ELASTIC_VIP"
    }
  ]
}
EOF
}

function getBMToken() {
	authAPI=`cat /opt/deploy/group_vars/all|grep -i BLUEMIX_AUTH_API|awk '{print $2}'`
	authUser=`cat /opt/deploy/group_vars/all|grep MONITOR_USER_ID|awk '{print $2}'`
	authCred=`cat /opt/deploy/group_vars/all|grep MONITOR_PASSWORD|awk '{print $2}'`
    tokenURL=$(echo $authAPI|sed "s/api/login/g")
    token=`curl -XPOST --silent https://$tokenURL/UAALoginServerWAR/oauth/token -H"Accept: application/json" -H"Authorization: Basic Y2Y6" -H"Content-Type: application/x-www-form-urlencoded" -d"grant_type=password&password=$authCred&scope=&username=$authUser"|jq .access_token|tr -d '"'`
    echo $token
}

token=$(getBMToken)
echo "start to update kafka shard to ${SHARD_REGISTER_URL}"
getKafkaShardData
resp=`curl -XPUT --silent -H "Content-Type: application/json" -H "X-Auth-Token: $token" -d @kafkashard/cluster.json "${SHARD_REGISTER_URL}" -k`
esshards=`echo $resp|grep -i 'esshards'`
[ -z "$esshards" ] && echo "Fail to update the kafka shard, response is $resp" && exit -1
echo "Successfully update the kafka cluster, kafkashardid: $kafkashardid."
