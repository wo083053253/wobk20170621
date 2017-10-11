#!/bin/bash
set -x

cd `dirname $0`/../

elk_stack_id=$(tail -n 1 elk_stack_id)
kafka_topic=$(tail -n 1 kafka_topic)
stack_id=$(tail -n 1 base_stack_id)
nginx_server_ip=$(tail -n 1 kafka_service_url)
stack_name=`cat /opt/deploy/group_vars/all|grep -i STACK_NAME|awk '{print $2}'`
#grabKafkaData
[ ! -f "/opt/deploy/hosts/multiserver_lb" ] && /opt/deploy/scripts/grabKafkaData.sh $nginx_server_ip $stack_id

#register shard
/opt/deploy/scripts/register_shard.sh $stack_name $elk_stack_id $kafka_topic $stack_id

#update kafka shard
/opt/deploy/scripts/update_kafka_shard.sh "$stack_id"
