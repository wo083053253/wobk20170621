#!/bin/bash
set -x
# the following vars are loaded from other vars
#export TENANTINFO_IP="10.171.15.235"
#export TENANTINFO_PORT="9099"
#export LOGMET_ENVIRONMENT="dev"

touch /var/log/logstash/monitorDiffKafkaTopic.log
exec >> /var/log/logstash/monitorDiffKafkaTopic.log
exec 2>&1

function changeInputConfigFile(){
  kafka_shard=$1
  i=$2

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

  cp /opt/00-input.conf /etc/logstash/conf.d/00-${shard_name}-input.conf
  sed -i "s|bootstrap_servers.*|bootstrap_servers => \"${kafkabrokers_list}\"|g" /etc/logstash/conf.d/00-${shard_name}-input.conf
  rm -f /etc/logstash/conf.d/00-input.conf 
}


if [ -z ${TENANTINFO_PORT} ]; then
  TENANTINFO_PORT=9099
fi

if [ -z ${LOGMET_ENVIRONMENT} ] && [ -z ${TENANTINFO_IP} ]; then
  echo "fail to get the logmet_environment or tenant_ip"
  exit -1
fi


kafka_shard=`curl -k -X GET https://${TENANTINFO_IP}:${TENANTINFO_PORT}/kafka_shard/list`
shard_length=`echo $kafka_shard|jq '.shards|length'`

kafka_name_list=''
if_kafka_close='No'
if_change_input='No'
for((i=0;i<$shard_length;i++))
do
  kafka_group=`echo $kafka_shard|jq .shards[$i]|jq '.group'|tr -d '"'`
  if [[ $kafka_group != ${LOGMET_ENVIRONMENT} ]];then
    continue
  fi

  shard_name=`echo $kafka_shard|jq .shards[$i]|jq '.name'|tr -d '"'`
  old_kafka_name_list=`find /etc/logstash/conf.d -name "00-*-input.conf"|awk '{split($0,a,"[--]");print a[2]}'`
  ifexist=`echo "${old_kafka_name_list[@]}" | grep -wq "${shard_name}" &&  echo "Yes" || echo "No"`

  kafka_status=`echo $kafka_shard|jq .shards[$i]|jq '.status'|tr -d '"'`

  if [[ $ifexist = "Yes" ]]; then
    if [[ $kafka_status = "closed" ]];then
      rm -f /etc/logstash/conf.d/00-${shard_name}-input.conf
      if_kafka_close="Yes"
      continue
    fi

    kafka_brokers_in_file=`less /etc/logstash/conf.d/00-${shard_name}-input.conf | awk -F "[bootstrap_servers]" '/bootstrap_servers/{print$0}' |awk -F "[=>]" '/bootstrap_servers/{print$3}'`
    kafka_brokers_in_file_length=`echo $kafka_brokers_in_file | awk '{printf("%d \n", split($0, var_arr, ","))}'`

    kafkabrokers_length_curl=`echo $kafka_shard|jq .shards[$i]|jq '.kafkabrokers|length'`
    if [[ $kafka_brokers_in_file_length -ne $kafkabrokers_length_curl ]];then
      rm -f /etc/logstash/conf.d/00-${shard_name}-input.conf
      changeInputConfigFile "${kafka_shard[*]}" $i;
      if_change_input="Yes"
      continue
    fi

    for((x=0;x<$kafkabrokers_length_curl;x++))
    do
      kafkabroker_curl=`echo $kafka_shard|jq .shards[$i]|jq .kafkabrokers[$x]|tr -d '"'`
      ifexist_broker=`echo "${kafka_brokers_in_file}" | grep -wq "${kafkabroker_curl}" &&  echo "Yes" || echo "No"`
      if [[ $ifexist_broker = "No" ]]; then
        rm -f /etc/logstash/conf.d/00-${shard_name}-input.conf
        changeInputConfigFile "${kafka_shard[*]}" $i;
        if_change_input="Yes"
        break
      fi
    done
  fi

  if [[ $ifexist != "Yes" ]]; then
    changeInputConfigFile "${kafka_shard[*]}" $i;
    if_change_input="Yes"
  fi
done

if [ $if_change_input = "Yes" -o $if_kafka_close = "Yes" ]; then
  supervisorctl stop logstash
  supervisorctl start logstash
fi

