#!/bin/bash
#set -x
#######################################
# ATE = AccessTrail Test Environment  #
#######################################
[ ${BASH_VERSINFO} -lt 4 ] && die "This script requires bash version 4 or above."
BASEDIR=`cd $(dirname ${BASH_SOURCE[0]}); pwd`

_die_()
{
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "$@"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
}

_on_exit()
{
    ATE_IMSG "Exiting from $0 ... "
}

function ATE_IMSG
{
    local imsg_verbosity=$1
    # NYI: verbosity for ATE_IMSG

    echo ""
    echo "---------------------------------------------------------------------"
    echo "INFO: $1 $2 $3 $4 "
    echo "---------------------------------------------------------------------"
}

shopt -s expand_aliases
alias die='_die_ "Line $(echo $LINENO): "'
trap "_on_exit" EXIT

declare -A DEPLOY_SYS
DEPLOY_SYS=(\
    ["DEPLOY_CONF"]="deploy.conf"\
    ["DEPLOY_ENVIRONMENT"]="dev"\
    ["STACK_NAME"]=""\
    ["DEPLOYMENT_SIZE"]=""\
    ["FR_NETWORK"]=""\
    ["PUB_NETWORK"]=""\
    ["AVAIL_ZONE"]=""\
    ["DEPLOY_IMAGE"]=""\
    ["CARBONRELAY_IP"]="10.171.15.228"\
    ["TIMEOUT"]="240" \
    ["ES_NAME"]="elasticsearch_1" \
    ["ES_NUM"]="1" \
    ["TOPIC"]="topic1" \
    ["BASE_STACK_NAME"]=""\
    ["REDSTONE_CRED"]="" \
    ["APT_SNAPSHOT"]="logging"
)

function _deploy_init
{
    # Obtain test configuration
    source ${BASEDIR}/${DEPLOY_SYS["DEPLOY_CONF"]}

    # Validate test configuration
    if [ -z "${DEPLOY_ENVIRONMENT}" -o \
         -z "${DEPLOY_STACK_NAME}" -o \
         -z "${DEPLOY_SIZE}" -o \
         -z "${DEPLOY_FR_NETWORK}" -o \
         -z "${DEPLOY_PUB_NETWORK}" -o \
         -z "${DEPLOY_BASE_STACK_NAME}" -o \
         -z "${DEPLOY_AVAIL_ZONE}" ]
    then
        _die_ "Incorrect deploy configuration, please check ${DEPLOY_SYS["DEPLOY_CONF"]}."
    fi

    # initialize DEPLOY_SYS
    DEPLOY_SYS["DEPLOY_ENVIRONMENT"]=${DEPLOY_ENVIRONMENT}
    DEPLOY_SYS["STACK_NAME"]=${DEPLOY_STACK_NAME}
    DEPLOY_SYS["DEPLOYMENT_SIZE"]="deployment-sizes/${DEPLOY_SIZE}.yaml"
    DEPLOY_SYS["FR_NETWORK"]=${DEPLOY_FR_NETWORK}
    DEPLOY_SYS["PUB_NETWORK"]=${DEPLOY_PUB_NETWORK}
    DEPLOY_SYS["BASE_STACK_NAME"]=${DEPLOY_BASE_STACK_NAME}

    if [ -z "${DEPLOY_IMAGE}" ]; then
        DEPLOY_SYS["DEPLOY_IMAGE"]=""
    else
        DEPLOY_SYS["DEPLOY_IMAGE"]="-P images={\"default\":\"${DEPLOY_IMAGE}\",\"elasticsearch_data\":\"${DEPLOY_IMAGE}\"}"
    fi

    if [ -z "${DEPLOY_AVAIL_ZONE}" ]; then
        DEPLOY_SYS["AVAIL_ZONE"]=""
    else
        DEPLOY_SYS["AVAIL_ZONE"]="-P availability_zone={\"default\":\"${DEPLOY_AVAIL_ZONE}\",\"kafka\":\"${DEPLOY_AVAIL_ZONE}\",\"elasticsearch_data_hot\":\"${DEPLOY_AVAIL_ZONE}\",\"elasticsearch_data_warm\":\"${DEPLOY_AVAIL_ZONE}\"}"
       
    fi

    if [ -z "${APT_SNAPSHOT}" ]; then
        DEPLOY_SYS["APT_SNAPSHOT"]="logging"
    else
        DEPLOY_SYS["APT_SNAPSHOT"]=${APT_SNAPSHOT}
    fi

    #redstone cred
    if [ -z "${REDSTONE_CRED}" ]; then
        DEPLOY_SYS["REDSTONE_CRED"]=""
    else
        DEPLOY_SYS["REDSTONE_CRED"]="-P redstone_magic=${REDSTONE_CRED}"
    fi

    [ -n "$ES_NAME" ] && DEPLOY_SYS["ES_NAME"]=${ES_NAME}
    [ -n "$TOPIC" ] && DEPLOY_SYS["TOPIC"]=${TOPIC}
    [ -n "$ES_NUM" ] && DEPLOY_SYS["ES_NUM"]=${ES_NUM}
    [ -n "$CARBONRELAY_IP" ] && DEPLOY_SYS["CARBONRELAY_IP"]=${CARBONRELAY_IP}
}

function DEPLOY_SETUP
{
    echo "---------------------------------------------------------------------"
    echo "### Deploy Env:             ${DEPLOY_SYS["DEPLOY_ENVIRONMENT"]}"
    echo "### Stack Name:             ${DEPLOY_SYS["STACK_NAME"]}"
    echo "### Deployment Size:        ${DEPLOY_SYS["DEPLOYMENT_SIZE"]}"
    echo "### Front Network:          ${DEPLOY_SYS["FR_NETWORK"]}"
    echo "### Public Network:         ${DEPLOY_SYS["PUB_NETWORK"]}"
    echo "### Availability Zone:          ${DEPLOY_SYS["AVAIL_ZONE"]}"
    echo "### Image:          ${DEPLOY_SYS["DEPLOY_IMAGE"]}"
    echo "### Carbonrelay IP:      ${DEPLOY_SYS["CARBONRELAY_IP"]}"
    echo "### Aptly Snapshot:        ${DEPLOY_SYS["APT_SNAPSHOT"]}"
    echo "### Redstone Cred:        ${DEPLOY_SYS["REDSTONE_CRED"]}"
    echo "### Base Stack Name:        ${DEPLOY_SYS["BASE_STACK_NAME"]}"
    echo "### ES Name:        ${DEPLOY_SYS["ES_NAME"]}"
    echo "### ES Num:        ${DEPLOY_SYS["ES_NUM"]}"
    echo "### Kafka Topic:        ${DEPLOY_SYS["TOPIC"]}"
    echo "---------------------------------------------------------------------"
}

######################################
# Init DEPLOY
_deploy_init

#display deploy
DEPLOY_SETUP

cd ${BASEDIR}/heat

kafka_shard_id=$(heat stack-list | grep ${DEPLOY_SYS["BASE_STACK_NAME"]} | awk '{print $2}')

[ -z $kafka_shard_id ] && echo "Base stack is invalid" && exit 1
# load_balancer_vips is wrong IP address
#kafka_service_ip=$(heat output-show ${base_stack}  load_balancer_vips  | jq .nginx_lb_ip | sed 's/[ ",]//g')
#example: valor1-dal10-i=10.177.9.72; valor1-dal10-e=169.46.98.175
#IP address should be from column 12 or 13

#kafka_service_str=$(nova list|grep ${DEPLOY_SYS["BASE_STACK_NAME"]} | grep -i nginx_lb | tail -1 | awk '{print $12'}|sed 's/[ ",;]//g')
#kafka_service_ip=${kafka_service_str#*=}

#if [[ ${kafka_service_ip:0:3}  != '10.' ]]; then
#   kafka_service_str=$(nova list|grep ${DEPLOY_SYS["BASE_STACK_NAME"]} | grep -i nginx_lb | tail -1 | awk '{print $13'}|sed 's/[ ",;]//g')
#   kafka_service_ip=${kafka_service_str#*=}
#fi

#neutron port-list | grep edge_prod_base_35  | grep edge_prod_base_35-nginx_lb-virtual_ip | grep -v _ext | awk '{print $11}'  |sed 's/[ ",;{}]//g'
#port name will be replaced with random string, we have to use base_xx to query ip address
stack_name=${DEPLOY_SYS["BASE_STACK_NAME"]}
suffix_stack_name=${stack_name#*base}
#check neutron client version, add tenant_id column on the latest neutron client
check_neutron_version=$(neutron port-list | grep tenant_id)
if [ -z "$check_neutron_version" ];
then
    kafka_service_ip=$(neutron port-list | grep "base"${suffix_stack_name} | grep nginx_lb | grep virtual_ip | grep -v _ext | awk '{print $11}'| sed 's/[ ",;{}]//g')
else
    kafka_service_ip=$(neutron port-list | grep "base"${suffix_stack_name} | grep nginx_lb | grep virtual_ip | grep -v _ext | awk '{print $13}'| sed 's/[ ",;{}]//g')
fi
echo "get kafka service ip address: $kafka_service_ip"
[ -z $kafka_service_ip ] && echo "kafka_service_ip is invalid" && exit 1

heat  stack-create ${DEPLOY_SYS["STACK_NAME"]}  \
--timeout ${DEPLOY_SYS["TIMEOUT"]} -e env/env.yaml \
-e ${DEPLOY_SYS["DEPLOYMENT_SIZE"]} \
-f logstash-elastic.yaml  \
-P kafka_service_url=${kafka_service_ip} \
-P kafka_shard_id=${kafka_shard_id} \
-P environment=${DEPLOY_SYS["DEPLOY_ENVIRONMENT"]} \
-P carbonrelay_address=${DEPLOY_SYS["CARBONRELAY_IP"]} \
-P internal_network=${DEPLOY_SYS["FR_NETWORK"]} \
-P external_network=${DEPLOY_SYS["PUB_NETWORK"]} \
-P kafka_topic=${DEPLOY_SYS["TOPIC"]} \
-P cluster_name=${DEPLOY_SYS["ES_NAME"]} \
-P apt_repo=${DEPLOY_SYS["APT_SNAPSHOT"]} \
-P cluster_num=${DEPLOY_SYS["ES_NUM"]} \
   ${DEPLOY_SYS["AVAIL_ZONE"]} ${DEPLOY_SYS["REDSTONE_CRED"]}

STATUS="CREATE_IN_PROGRESS"
sleep 5

FAILED_STATUS_COUNT=0
while true; do
    STATUS=$(heat stack-list --filters name=${DEPLOY_SYS["STACK_NAME"]} --limit 1 | grep "${DEPLOY_SYS["STACK_NAME"]}" | awk '{print $6}')
    echo "`date` : ${STATUS}"

    case "$STATUS" in
        (CREATE_IN_PROGRESS)
            FAILED_STATUS_COUNT=0
            sleep 300
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
heat stack-show ${DEPLOY_SYS["STACK_NAME"]}

