#!/bin/bash
set -x
touch /var/log/logstash/runLogstashIndex.log
exec >> /var/log/logstash/runLogstashIndex.log
exec 2>&1
#
# Run the logstash indexer within the docker container

# Replace the variables with the environment variables
HOSTNAME=`hostname`

# Set defaults for optional parameters
if [ -z ${CLUSTER_CACHE_SIZE} ]; then
  CLUSTER_CACHE_SIZE=1000
fi

if [ -z ${CACHE_EXPIRATION_INTERVAL} ]; then
  CACHE_EXPIRATION_INTERVAL=3600
fi

if [ -z ${TENANTINFO_PORT} ]; then
  TENANTINFO_PORT=9099
fi

sudo apt-get -y install jq 
kafka_shard=`curl -k -X GET https://${TENANTINFO_IP}:${TENANTINFO_PORT}/kafka_shard/list`
SHARDSIZE=`echo $kafka_shard|jq '.shards|length'`

for((i=0;i<$SHARDSIZE;i++))
do
  kafka_group=`echo $kafka_shard|jq .shards[$i]|jq '.group'|tr -d '"'`
  if [[ $kafka_group != ${LOGMET_ENVIRONMENT} ]];then
    continue
  fi
  shard_name=`echo $kafka_shard|jq .shards[$i]|jq '.name'|tr -d '"'`

  kafkabrokers_list=''
  kafkabrokers_length=`echo $kafka_shard|jq .shards[$i]|jq '.kafkabrokers|length'`
  for((j=0;j<$kafkabrokers_length;j++))
  do
    kafkabrokers=`echo $kafka_shard|jq .shards[$i]|jq .kafkabrokers[$j]|tr -d '"'`
    kafkabrokers_list="$kafkabrokers_list$kafkabrokers,"
  done
  kafkabrokers_list=`echo ${kafkabrokers_list%,*}`

  shardzookeeper_list=''
  shardzookeeper_length=`echo $kafka_shard|jq .shards[$i]|jq '.zookeeper|length'`
  for((t=0;t<$shardzookeeper_length;t++))
  do
    shardzookeeper=`echo $kafka_shard|jq .shards[$i]|jq .zookeeper[$t]|tr -d '"'`
    shardzookeeper_list="$shardzookeeper_list$shardzookeeper,"
  done
  shardzookeeper_list=`echo ${shardzookeeper_list%,*}`

  cp /etc/logstash/conf.d/00-input.conf /opt/00-input.conf
  rm -f /etc/logstash/conf.d/00-input.conf
  cp /opt/00-input.conf /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_TOPIC_ID|${TOPIC_ID}|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_ZOOKEEPER_SERVERS|${shardzookeeper_list}|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_KAFKA_SERVERS|$kafkabrokers_list|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_CONSUMER_THREADS|${LS_CONSUMER_THREADS}|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_TENANTINFO_IP|${TENANTINFO_IP}|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_TENANTINFO_PORT|${TENANTINFO_PORT}|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_CLUSTER_CACHE_SIZE|${CLUSTER_CACHE_SIZE}|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_CACHE_EXPIRATION_INTERVAL|${CACHE_EXPIRATION_INTERVAL}|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_ELASTICSEARCH_CLUSTERNAME|${ELASTICSEARCH_CLUSTER}|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_GROUP_ID|${CONSUMER_GROUP_ID}|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_REBALANCE_MAX_RETRIES|${REBALANCE_MAX_RETRIES}|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|REPLACE_REBALANCE_BACKOFF_MS|${REBALANCE_BACKOFF_MS}|g" /etc/logstash/conf.d/00-${shard_name}-input.conf

done

sed -i "s|REPLACE_STATSD_HOST|${STATSD_HOST}|g" /etc/logstash/conf.d/99-output.conf
sed -i "s|REPLACE_STATSD_PORT|${STATSD_PORT}|g" /etc/logstash/conf.d/99-output.conf
sed -i "s|REPLACE_METRICS_HOST|${METRICS_HOST}|g" /etc/logstash/conf.d/99-output.conf
sed -i "s|REPLACE_METRICS_PORT|${METRICS_PORT}|g" /etc/logstash/conf.d/99-output.conf
sed -i "s|REPLACE_ELASTICSEARCH_HTTP_NODE_LIST|${ELASTICSEARCH_HTTP_NODE_LIST/\,/\"\,\"}|g" /etc/logstash/conf.d/99-output.conf
sed -i "s|REPLACE_ELASTICSEARCH_CLUSTERNAME|${ELASTICSEARCH_CLUSTER}|g" /etc/logstash/conf.d/99-output.conf
sed -i "s|REPLACE_NODE_NAME|${HOSTNAME}|g" /etc/logstash/conf.d/99-output.conf
sed -i "s|carbon-relay|${METRICS_HOST}|g" /etc/logstash/conf.d/99-output.conf
sed -i "s|REPLACE_FLUSH_SIZE|${FLUSH_SIZE}|g" /etc/logstash/conf.d/99-output.conf

 
# Here we look for environment-variables as feature-flags to turn on various if-code blocks in our filters
if [ "${ESALIAS_ENABLED}" == "1" ]; then
  # Used for turning on alias support (i.e. single index for multiple users)
  find /etc/logstash/conf.d -name "*.conf" | xargs sed -i "s|ESALIAS_FUNCTION_ENABLE|true|g"
fi

if [ "${RENAME_FILTER_ENABLED}" == "1" ]; then
  # Used for turning on the type-based suffix-addition filter logic
  find /etc/logstash/conf.d -name "*.conf" | xargs sed -i "s|RENAME_FILTER_ENABLE|true|g"
fi

# Used to define the date on logs in which ESALIAS_ENABLED becomes active
find /etc/logstash/conf.d -name "*.conf" | xargs sed -i "s|REPLACE_ESALIAS_ENABLE_DATE|${ESALIAS_ENABLE_DATE}|g"

# Defaults ( copied from the logstash.conf upstart )
# Note: these are set in the Dockerfile  to allow
# you to alter the configurations via the container start

PATH=/bin:/usr/bin
LS_HOME=/var/lib/logstash
LS_CONF_DIR="/etc/logstash/conf.d/**/*.conf"
BATCH_SIZE=$((${FLUSH_SIZE}/${WORKERS}))

HOME="${HOME:-$LS_HOME}"
# Reset filehandle limit
ulimit -n ${LS_OPEN_FILES}
cd "${LS_HOME}"

# Export variables
export PATH HOME LS_HEAP_SIZE LS_JAVA_OPTS LS_USE_GC_LOGGING

