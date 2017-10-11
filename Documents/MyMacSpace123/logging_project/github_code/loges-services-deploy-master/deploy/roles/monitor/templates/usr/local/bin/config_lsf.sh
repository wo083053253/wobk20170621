#!/bin/bash
set -x
#
#
# Update the mt-logstash-forwarder configuration
/usr/local/bin/overrideHosts.sh

MY_HOSTNAME=`hostname`

rm /etc/supervisor/conf.d/config-lsf.conf
echo "" > /etc/supervisor/conf.d/monitor-lsf-supervisor.conf

IFS=","
for es_cluster_index in ${ES_CLUSTERS_TO_MONITOR}
do
    BLUEMIX_LOGGING_TOKEN=""
    while [ "${BLUEMIX_LOGGING_TOKEN}" == "" ]; do
        sleep 2
        result=`curl -k -XPOST -d "user=${BLUEMIX_USERID}&passwd=${BLUEMIX_PASSWORD}&space=monitor-space-${es_cluster_index}&organization=${BLUEMIX_ORG_NAME}" https://${LOGMET_API_SERVER}/login`
        BLUEMIX_LOGGING_TOKEN=`echo "$result" | grep "logging_token" | awk '{print $2;}' | tr -d ',' | tr -d '"' `
        BLUEMIX_SPACE_ID=`echo "$result" | grep "space_id" | awk '{print $2;}' | tr -d '",' `
    done

    #if [ $MULTI_CLUSTER_ES_ENABLED -eq 1 ]; then
    #	curl -k -X GET "https://${TENANTINFO_LB_IP}:9099/cluster/set?tenant_id=${BLUEMIX_SPACE_ID}&cluster_number=elasticsearch_${es_cluster_index}"
	#fi

    mkdir -p /etc/mt-logstash-forwarder/monitor-space-$es_cluster_index/conf.d
    cp /usr/local/bin/lsf.conf.template /etc/mt-logstash-forwarder/monitor-space-$es_cluster_index/conf.d/lsf.conf
    sed -i "s|REPLACE_HOSTNAME|${MY_HOSTNAME}|g" /etc/mt-logstash-forwarder/monitor-space-$es_cluster_index/conf.d/lsf.conf
    sed -i "s|REPLACE_OPVIS_HOST|${LOGS_DATA_COLLECTION_SERVER}|g" /etc/mt-logstash-forwarder/monitor-space-$es_cluster_index/conf.d/lsf.conf
    sed -i "s|REPLACE_SPACEID|${BLUEMIX_SPACE_ID}|g" /etc/mt-logstash-forwarder/monitor-space-$es_cluster_index/conf.d/lsf.conf
    sed -i "s|REPLACE_LOGGING_TOKEN|${BLUEMIX_LOGGING_TOKEN}|g" /etc/mt-logstash-forwarder/monitor-space-$es_cluster_index/conf.d/lsf.conf

    cp /usr/local/bin/log_monitor.conf.template /etc/mt-logstash-forwarder/monitor-space-$es_cluster_index/conf.d/log_monitor.conf
    sed -i "s|REPLACE_LOG_FILE_NAME|log_monitor_${es_cluster_index}|g" /etc/mt-logstash-forwarder/monitor-space-$es_cluster_index/conf.d/log_monitor.conf

    echo "" >> /etc/supervisor/conf.d/monitor-lsf-supervisor.conf
    echo "[program:logstash-forwarder-$es_cluster_index]" >> /etc/supervisor/conf.d/monitor-lsf-supervisor.conf
    echo "command=/opt/mt-logstash-forwarder/bin/mt-logstash-forwarder -config /etc/mt-logstash-forwarder/monitor-space-$es_cluster_index/conf.d" >> /etc/supervisor/conf.d/monitor-lsf-supervisor.conf
    echo "stdout_logfile=/var/log/mt-logstash-forwarder-$es_cluster_index.log" >> /etc/supervisor/conf.d/monitor-lsf-supervisor.conf
    echo "redirect_stderr=true" >> /etc/supervisor/conf.d/monitor-lsf-supervisor.conf
    echo "priority=1" >> /etc/supervisor/conf.d/monitor-lsf-supervisor.conf
    supervisorctl reread
    supervisorctl add logstash-forwarder-$es_cluster_index
done
