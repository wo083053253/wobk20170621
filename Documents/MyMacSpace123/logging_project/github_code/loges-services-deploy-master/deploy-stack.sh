#!/bin/bash

BASEDIR=`cd $(dirname ${BASH_SOURCE[0]}); pwd`

stack_name=$1
environment=$2
topic=$3
es_name=$4
es_num=$5
avail_zone=$6
carbonrelay_ip=$7
base_stack=$8
FR_NETWORK=$9
PUB_NETWORK=$10

deploy_size=$environment
#for prestaging environment, deployment_size should be prestaging, environment should be lon02-stage1
[ $environment = "prestaging" ] && environment="lon02-stage1"

[ -z $carbonrelay_ip ] && carbonrelay_ip=10.176.109.169

if [ -n "${avail_zone}" ]; then
    az_param="-P availability_zone={\"default\":\"${avail_zone}\",\"kafka\":\"${avail_zone}\",\"elasticsearch_data_hot\":\"${avail_zone}\",\"elasticsearch_data_warm\":\"${avail_zone}\"}"
else
    az_param=""
fi

cd ${BASEDIR}/heat

kafka_shard_id=$(heat stack-list | grep ${base_stack} | awk '{print $2}')

[ -z $kafka_shard_id ] && echo "Base stack is invalid" && exit 1
# load_balancer_vips is wrong IP address
#kafka_service_ip=$(heat output-show ${base_stack}  load_balancer_vips  | jq .nginx_lb_ip | sed 's/[ ",]//g')
#example: valor1-dal10-i=10.177.9.72; valor1-dal10-e=169.46.98.175
#IP address should be from column 12 or 13

#kafka_service_str=$(nova list|grep ${base_stack} | grep -i nginx_lb | awk '{print $12'}|sed 's/[ ",;]//g')
#kafka_service_ip=${kafka_service_str#*=}

#if [[ ${kafka_service_ip:0:3}  != '10.' ]]; then
#   kafka_service_str=$(nova list|grep ${base_stack} | grep -i nginx_lb | awk '{print $13'}|sed 's/[ ",;]//g')
#   kafka_service_ip=${kafka_service_str#*=}
#fi
#neutron port-list | grep edge_prod_base_35  | grep edge_prod_base_35-nginx_lb-virtual_ip | grep -v _ext | awk '{print $11}'  |sed 's/[ ",;{}]//g'
kafka_service_ip=$(neutron port-list | grep  ${base_stack} | grep nginx_lb | grep virtual_ip | grep -v _ext | awk '{print $11}'| sed 's/[ ",;{}]//g')
[ -z $kafka_service_ip ] && echo "kafka_service_ip is invalid" && exit 1


heat  stack-create ${stack_name} \
--timeout 240 -e env/env.yaml \
-e deployment-sizes/${deploy_size}.yaml \
-f logstash-elastic.yaml  \
-P kafka_service_url=${kafka_service_ip} \
-P kafka_shard_id=${kafka_shard_id} \
-P environment=${environment}  \
-P carbonrelay_address=${carbonrelay_ip} \
-P internal_network=${FR_NETWORK} \
-P external_network=${PUB_NETWORK} \
-P kafka_topic=${topic} \
-P cluster_name=${es_name} \
-P cluster_num=${es_num} ${az_param}


STATUS="CREATE_IN_PROGRESS"
sleep 5

FAILED_STATUS_COUNT=0
while true; do
    STATUS=$(heat stack-list --filters name=${stack_name} --limit 1 | grep "${stack_name} " | awk '{print $6}')
    echo "`date` : ${STATUS}"

    case "$STATUS" in
        (CREATE_IN_PROGRESS)
            FAILED_STATUS_COUNT=0
            sleep 60
            ;;
        (CREATE_COMPLETE)
            break
            ;;
        (CREATE_FAILED)
            break
            ;;
        (*)
            FAILED_STATUS_COUNT=$(( $FAILED_STATUS_COUNT + 1 ))
            if [[ "$FAILED_STATUS_COUNT" -ge 3 ]]; then
                STATUS="CREATE_FAILED"
                break
            fi
            ;;
    esac
done

# Show the details now that we are finished
heat stack-show ${stack_name}

