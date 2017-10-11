#!/bin/bash
debug=0
cd `dirname $0`/../

if [ "$1" == "-debug" ]; then
    debug=1
fi

client_auth=`cat group_vars/all | grep tenantinfo_client_auth | awk '{print $2;}'`
monitorUser=`cat group_vars/all | grep MONITOR_USER_ID |  awk '{print $2;}'`
monitorUserPwd=`cat group_vars/all | grep MONITOR_PASSWORD | awk '{print $2;}'`
monitorOrg=`cat group_vars/monitor_servers | grep MONITOR_ORG | awk '{print $2;}'`

alogmon_lb=`cat floatings/alogmon_lb`

# Retrieve the spaceid for the tests
result=`curl -s -k -XPOST -d"user=${monitorUser}&passwd=${monitorUserPwd}&space=monitor-space-1&organization=${monitorOrg}" http://${alogmon_lb}:8777/login`

bearerToken=`echo $result | awk '{printf $3}' | cut -d'"' -f2`
loggingToken=`echo $result | awk '{printf $5}' | cut -d'"' -f2`
spaceid=`echo $result | awk '{printf $9}' | cut -d'"' -f2`

[ $debug == 0 ] || echo "spaceid is ${spaceid}"

testTenantinfo()
{
    tenantinfo_lb=`cat floatings/tenantinfo_lb`

    [ $debug == 0 ] || echo "client_auth: $client_auth"
    [ $debug == 0 ] || echo "tenantinfo_lb: $tenantinfo_lb"

    result=`curl -s -k -d"{\"client-auth\": \"${client_auth}\", \"space-id\": \"${spaceid}\"}" https://${tenantinfo_lb}:9099/loggingpassword`

    [ $debug == 0 ] || echo "tenantinfo result : $result "

    check=`echo "$result" | grep "logging-password"`

    if [ "$check" != "" ]; then
        echo "tenantinfo: Success"
    else
        echo "tenantinfo: Failed"
    fi
}




testFauxKeystone()
{
    # Test faux-keystone
    fauxks_lb=`cat floatings/fauxkeystone_lb`
    [ $debug == 0 ] || echo "fauxkeystone_lb: $fauxks_lb"

    result=`curl -s -k -XPOST -d"{ \"auth\" : { \"passwordCredentials\": {\"username\": \"${monitorUser}\", \"password\": \"${monitorUserPwd}\" }, \"TenantName\": \"${monitorUser}|dev\" }}" https://${fauxks_lb}:443/v2.0/tokens`
    [ $debug == 0 ] || echo "Fauxkeystone result from user/password: $result "

    id=$(echo "$result" | cut -d'"' -f8)
    [ $debug == 0 ] || echo "id : ${id}"
    result=`curl -s -k -XPOST -d"{ \"auth\": { \"tenantName\": \"${monitorUser}\", \"token\": { \"id\": \"${id}\" } } }" https://${fauxks_lb}:443/v2.0/tokens`

    [ $debug == 0 ] || echo "Fauxkeystone result from id: $result"

    count=$(echo "$result" | grep "roles_links" | wc -l)
    if [ "$count" == "1" ]; then
        echo "Faux Keystone: Success"
    else
        echo "Faux Keystone: Failed"
    fi
}


testAlogmonLB()
{
    alogmon_lb=`cat floatings/alogmon_lb`
    [ $debug == 0 ] || echo "alogmon_lb: $alogmon_lb"

    testAlogmon $alogmon_lb
}


testAlogmonServers()
{
    for server in $(tail -n +2 hosts/alogmon); do
        testAlogmon $server
    done
}

testAlogmon()
{
    alogmon_host=$1
    [ $debug == 0 ] || echo "alogmon_host: $alogmon_host"

    result=`curl -s -k -XPOST -d"user=${monitorUser}&passwd=${monitorUserPwd}&space=monitor-space-1&organization=${monitorOrg}" http://${alogmon_host}:8777/login`

    [ $debug == 0 ] || echo "Alogmon result : $result "

    # Validate the bearer token and logging passwords are not empty

    bearerToken=`echo $result | awk '{printf $3}' | cut -d'"' -f2`
    loggingToken=`echo $result | awk '{printf $5}' | cut -d'"' -f2`

    if [ "$bearerToken" != "" ] && [ "$loggingToken" != "" ] ; then
        echo "Alogmon: Success"
    else
        echo "Alogmon: Failed"
    fi
}


testKafka() {

    for i in $(tail -n +2 hosts/zookeeper); do
        zookeeper_url="$zookeeper_url,""$i:2181"
    done
    zookeeper_url="${zookeeper_url/,/}"


    [ $debug == 0 ] || echo "Zookeeper URL : $zookeeper_url"

    for host in $(tail -n +2 hosts/kafka); do

        [ $debug == 0 ] || echo "Processing IP $host"

        cmd="/opt/kafka/bin/kafka-topics.sh --describe --zookeeper $zookeeper_url"

        result=`ssh -tt $host sudo docker exec -it kafka $cmd`
        count=`echo "$result" | wc -l`
        if (( $count >= 20 )); then
            echo "Kafka Topics: Success"
        else
            [ $debug == 0 ] || echo "kafka query for topics returned : $result"
            echo "Kafka Topics: Failed"
        fi

        # If nothing is being written, this can hang indefinitely, so put in a timeout.
        cmd="timeout 60 /opt/kafka/bin/kafka-console-consumer.sh --topic alchemy-logs --max-messages 1 --from-beginning --zookeeper $zookeeper_url"
        result=$(ssh -tt $host sudo docker exec -it kafka $cmd)
        [ $debug == 0 ] || echo $result
        count=$(echo "${result}" | grep "Consumed 1 message" | wc -l)
        if [ "$count" == "0" ]; then
            count=$(echo "${result}" | grep "Processed a total of 1 messages" | wc -l)
        fi

        if [ "$count" == "1" ]; then
            echo "Kafka Log Query: Success"
        else
            echo "Kafka Log Query: Failed"
        fi
    done

    for i in $(tail -n +2 hosts/zookeeper); do
        zookeeper_url_metrics="$zookeeper_url_metrics,""$i:2181"
    done
    zookeeper_url_metrics="${zookeeper_url_metrics/,/}"
    zookeeper_url_metrics="${zookeeper_url_metrics}/metrics"


    [ $debug == 0 ] || echo "Zookeeper URL Metrics: $zookeeper_url_metrics"

    if [ -e "hosts/kafkametrics" ]; then
       for host in $(tail -n +2 hosts/kafkametrics); do
          # If nothing is being written, this can hang indefinitely, so put in a timeout.
          cmd="timeout 60 /opt/kafka/bin/kafka-console-consumer.sh --topic alchemy-metrics --max-messages 1 --from-beginning --zookeeper $zookeeper_url_metrics"
          result=`ssh -tt $host sudo docker exec -it kafkametrics $cmd`
          [ $debug == 0 ] || echo $result
          count=$(echo "${result}" | grep "Consumed 1 message" | wc -l)
          if [ "$count" == "0" ]; then
              count=$(echo "${result}" | grep "Processed a total of 1 messages" | wc -l)
          fi

          if [ "$count" == "1" ]; then
              echo "Kafka Metric Query: Success"
          else
              echo "Kafka Metric Query: Failed"
          fi
       done
    fi
}

testES() {
    for host_file in $(ls /opt/deploy/hosts/elasticsearch_http*); do
        cluster_num="${host_file//[!0-9]/}"
        esHost=`tail -n1 ${host_file}`
        [ $debug == 0 ] || echo "ES Http URL : $esHost"

        health=$(curl -s http://${esHost}:9200/_cat/health)
        [ $debug == 0 ] || echo "ES cluster health : $health"

        healthy=$(echo "$health" | grep "green" | wc -l )
        if [ "${healthy}" == "1" ]; then
            echo "ES Http $cluster_num: Success"
        else
            echo "ES Http $cluster_num: Failed"
        fi
    done
}

testDashboardES() {
    if [ -f /opt/deploy/hosts/dashboard_es ]; then
        for es in $(tail -n +2 hosts/dashboard_es); do
            health=$(curl -s http://${es}:9200/_cat/health)
            [ $debug == 0 ] || echo "Dashboard ES $es health : $health"

            healthy=$(echo "$health" | grep "green" | wc -l )
            if [ "${healthy}" == "1" ]; then
                echo "Dashboard ES $es Http: Success"
            else
                echo "Dashboard ES $es Http: Failed"
            fi
        done
    else
        echo " Dashboard ES: not configured"        
    fi        
}


testMonitor() {
    monitorHost=`tail -n1 /opt/deploy/hosts/monitor`
    [ $debug == 0 ] || echo "Monitor Host : $monitorHost"

    cached_log_status=$(curl -s http://${monitorHost}:8080/cached_log_status)
    [ $debug == 0 ] || echo "cached_log_status : $cached_log_status"

    log_healthy=$(echo "$cached_log_status" | grep "200" | wc -l )
    if [ "${log_healthy}" == "1" ]; then
        echo "Monitor cached_log_status: Success"
    else
        echo "Monitor cached_log_status: Failed"
    fi

    cached_metrics_status=$(curl -s http://${monitorHost}:8080/cached_metrics_status)
    [ $debug == 0 ] || echo "cached_metrics_status : $cached_metrics_status"
    
    metrics_healthy=$(echo "$cached_metrics_status" | grep "200" | wc -l )
    if [ "${metrics_healthy}" == "1" ]; then
        echo "Monitor cached_metrics_status: Success"
    else
        echo "Monitor cached_metrics_status: Failed"
    fi
}

testMonitor
testES
testDashboardES
testTenantinfo
testFauxKeystone
testAlogmonLB
testAlogmonServers
testKafka
