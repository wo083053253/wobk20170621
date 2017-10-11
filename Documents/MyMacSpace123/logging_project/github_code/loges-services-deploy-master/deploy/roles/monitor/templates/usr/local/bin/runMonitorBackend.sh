#!/bin/bash
#
# Start the monitor backend application within a docker container 
# 
# The monitor.py requires two configuration files in the same directory
#   1) monitor.conf - configures the systems we connect to
#	2) logging.conf - configures the logging system used by the backend
/usr/local/bin/overrideHosts.sh

cd /opt/monitor

MY_HOSTNAME=`hostname`

CONFIG_FILE=/opt/monitor/monitors.conf
# Substitute various configurations within the monitor config file
sed -i "s|REPLACE_LOGMET_API_SERVER|${LOGMET_API_SERVER}|g" ${CONFIG_FILE}
sed -i "s|REPLACE_LOGS_DATA_COLLECTION_SERVER|${LOGS_DATA_COLLECTION_SERVER}|g" ${CONFIG_FILE}
sed -i "s|REPLACE_METRICS_DATA_COLLECTION_SERVER|${METRICS_DATA_COLLECTION_SERVER}|g" ${CONFIG_FILE}
sed -i "s|REPLACE_ES_CLUSTERS_TO_MONITOR|${ES_CLUSTERS_TO_MONITOR}|g" ${CONFIG_FILE}


sed -i "s|REPLACE_BLUEMIX_USERID|${BLUEMIX_USERID}|g" ${CONFIG_FILE}
sed -i "s|REPLACE_BLUEMIX_PASSWORD|${BLUEMIX_PASSWORD}|g" ${CONFIG_FILE}

#temp fix for logging token racing condition, tenantinfo will be fixed to handle it.
sleep 10

#use  monitor-space-1 for metric monitor
LOGGING_TOKEN=""
while [ "${LOGGING_TOKEN}" == "" ]; do
    sleep 5
    
    result=`curl -k -XPOST -d "user=${BLUEMIX_USERID}&passwd=${BLUEMIX_PASSWORD}&space=monitor-space-1&organization=${BLUEMIX_ORG_NAME}" https://${LOGMET_API_SERVER}/login`
    BLUEMIX_SPACE_ID=`echo "$result" | grep "space_id" | awk '{print $2;}' | tr -d '",' `
    LOGGING_TOKEN=`echo "$result" | grep "logging_token" | awk '{print $2;}' | tr -d ',' | tr -d '"'`
done

sed -i "s|REPLACE_BLUEMIX_SPACE_ID|${BLUEMIX_SPACE_ID}|g" ${CONFIG_FILE}
sed -i "s|REPLACE_BLUEMIX_ORG_NAME|${BLUEMIX_ORG_NAME}|g" ${CONFIG_FILE}


sed -i "s|REPLACE_GRAPHITE_ENVIRONMENT|${GRAPHITE_ENVIRONMENT}|g" ${CONFIG_FILE}
sed -i "s|REPLACE_KAFKA_LAG_LOGS_DOWN_THRESHOLD|${KAFKA_LAG_LOGS_DOWN_THRESHOLD}|g" ${CONFIG_FILE}
sed -i "s|REPLACE_KAFKA_LAG_METRICS_DOWN_THRESHOLD|${KAFKA_LAG_METRICS_DOWN_THRESHOLD}|g" ${CONFIG_FILE}

sed -i "s|REPLACE_HOSTNAME|${MY_HOSTNAME}|g" ${CONFIG_FILE}

# Start the server process 
echo "Starting the monitor.py python process - Backend Process"

python monitors.py

echo "monitor.py exiting"
