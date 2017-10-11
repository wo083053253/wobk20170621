#!/bin/bash
#set -x
exec >> /var/log/ansible/post_deploy.log
exec 2>&1

[ $# -lt 2 ] && echo "$0 <shard_url> <shard_id>" && exit -1
cd `dirname $0`/../
shard_url=$1
shard_id=$2
mkdir -p /opt/deploy/kafkashard

function getBMToken() {
	authAPI=`cat /opt/deploy/group_vars/all|grep -i BLUEMIX_AUTH_API|awk '{print $2}'`
	authUser=`cat /opt/deploy/group_vars/all|grep MONITOR_USER_ID|awk '{print $2}'`
	authCred=`cat /opt/deploy/group_vars/all|grep MONITOR_PASSWORD|awk '{print $2}'`
    tokenURL=$(echo $authAPI|sed "s/api/login/g")
    token=`curl -XPOST --silent https://$tokenURL/UAALoginServerWAR/oauth/token -H"Accept: application/json" -H"Authorization: Basic Y2Y6" -H"Content-Type: application/x-www-form-urlencoded" -d"grant_type=password&password=$authCred&scope=&username=$authUser"|jq .access_token|tr -d '"'`
    echo $token
}

function getShardData() {
    mkdir -p /opt/deploy/kafkashard
    bmtoken=$(getBMToken)
    if [[ $shard_url =~ "http" ]]; then
    	shard_url=${shard_url%/}/kafka_shard/$shard_id
    else
    	shard_url=https://${shard_url%/}/kafka_shard/$shard_id
    fi
    echo "start to grab shard data from $shard_url"
    resultcode=`curl -XGET -H "X-Auth-Token: $bmtoken" "$shard_url" -w "%{http_code}" -o /opt/deploy/kafkashard/data.json -k`
    if [ $resultcode != 200 ]; then
        echo "fail to get kafka shard data from $shard_url."
        exit -1
    fi
    echo "[kafka_servers]" > /opt/deploy/hosts/kafka
    while read line;
    do
        echo ${line%:9092} >> /opt/deploy/hosts/kafka
    done < <(jq -r .kafkabrokers[] < /opt/deploy/kafkashard/data.json)
    echo "[zookeeper_servers]" > /opt/deploy/hosts/zookeeper
    while read line;
    do
        echo ${line%:2181} >> /opt/deploy/hosts/zookeeper
    done < <(jq -r .zookeeper[] < /opt/deploy/kafkashard/data.json)
    nginxlb=`jq -r .nginxlb < /opt/deploy/kafkashard/data.json`
    cat > /opt/deploy/hosts/nginx_lb << EOF
[nginx_lb_servers]
$nginxlb
EOF
    multiserverlb=`jq -r .multiserverlb < /opt/deploy/kafkashard/data.json`
    cat > /opt/deploy/hosts/multiserver_lb << EOF
[multiserver_lb_servers]
$multiserverlb
EOF
    multilumberjacklb=`jq -r .lumberjacklb < /opt/deploy/kafkashard/data.json`
    #put mtlumberjacklb to group_vars for mt-logstash-forwarder
    echo "mtlumberjack_lb_ip: $multilumberjacklb" >> /opt/deploy/group_vars/all
    cat > /opt/deploy/hosts/mtlumberjack_lb << EOF
[mtlumberjack_lb_servers]
$multilumberjacklb
EOF
}

getShardData
