#!/bin/bash
set -x
# Configuration and startup for collectd
# - this script is invoked by the supervisord process when the container
#   is started.
#
# This script expects the following variables to be provided :
#  HOSTNAME - the name of the host for metrics purposes
#  METRICS_HOST - the name of the carbon-relay server we are sending metrics to
#  METRICS_PORT - the port of the carbon-relay server we are sending metrics to
#  GRAPHITE_ENVIRONMENT - the prefix of the metrics ( ie. <spaceid>.prod or <spaceid>.stage1 )
#  CLUSTER_NAME - the name of the cluster ( ie. lumberjack, logstash, kafka )
/usr/local/bin/overrideHosts.sh

MY_HOSTNAME=`hostname`

#temp fix for logging token racing condition, tenantinfo will be fixed to handle it.
MONITOR_LOGGING_TOKEN=""
while [ "${MONITOR_LOGGING_TOKEN}" == "" ]; do
    sleep 5

    result=`curl -k -XPOST -d "user=${BLUEMIX_USERID}&passwd=${BLUEMIX_PASSWORD}&space=monitor-space-1&organization=${BLUEMIX_ORG_NAME}" https://${LOGMET_API_SERVER}/login`
    MONITOR_SPACE_ID=`echo "$result" | grep "space_id" | awk '{print $2;}' |tr -d '",' `
    MONITOR_LOGGING_TOKEN=`echo "$result" | grep "logging_token" | awk '{print $2;}' | tr -d ',' | tr -d '"'`
done

echo "Starting runCollectd.sh - environment settings :"
echo "HOSTNAME:            ${MY_HOSTNAME}"
echo "LOGMET_HOST:         ${LOGMET_DATA_COLLECTION_SERVER}"
echo "GRAPHITE_SPACE_ID:   ${MONITOR_SPACE_ID}"
echo "LOGGING_TOKEN:       ${MONITOR_LOGGING_TOKEN}"
echo "METRICS_DATA_COLLECTION_SERVER: ${METRICS_DATA_COLLECTION_SERVER}"

if [ "${METRICS_DATA_COLLECTION_SERVER}" != "" ]; then
    # Override the old logging value if the new configuration exists
    LOGMET_DATA_COLLECTION_SERVER=${METRICS_DATA_COLLECTION_SERVER}
fi

# Logic for the multitenant collectd conf file deletion works the following way:
# in the monitor case, we are certain that we will be sending metrics to local stack's
# internal endpoint. Now, we have two configs: one with local stack's MT config
# and another with BOTH internal_monitor & local mt endpoint.
# If INTERNAL_METRICS_TARGET is defined then internal writer and local MT
# conf are used; else only MT config is used

CONF_DIR="/etc/collectd/collectd.conf.d"

if [ -z ${INTERNAL_METRICS_TARGET} ]; then
    MT_WRITE_GRAPHITE=$CONF_DIR/mt-write-graphite.conf
else
    MT_WRITE_GRAPHITE=$CONF_DIR/internal_mt_writer.conf
    rm -rf $CONF_DIR/mt-write-graphite.conf
fi
REGEX_FILE=$CONF_DIR/chain.match_regex

# Metric we are checking : REPLACE_BLUEMIX_SPACE_ID.monitor.REPLACE_HOSTNAME.cpu-0.cpu-system
sed -i "s|REPLACE_HOSTNAME|${MY_HOSTNAME}|g" ${MT_WRITE_GRAPHITE}
sed -i "s|REPLACE_SPACE_ID|${MONITOR_SPACE_ID}|g" ${MT_WRITE_GRAPHITE}
sed -i "s|REPLACE_OPVIS_HOST|${LOGMET_DATA_COLLECTION_SERVER}|g" ${MT_WRITE_GRAPHITE}
sed -i "s|REPLACE_LOGGING_TOKEN|${MONITOR_LOGGING_TOKEN}|g" ${MT_WRITE_GRAPHITE}

# add plugin to chain if it doesnt already exist
if ! grep -q ${LOGMET_DATA_COLLECTION_SERVER} $REGEX_FILE; then
    regex_var='Plugin "write_metric_mtlumberjack/'${LOGMET_DATA_COLLECTION_SERVER}'/9095"'
    sed -i "/ADD_WRITE_TARGET_HERE/a $regex_var" $REGEX_FILE
    unset regex_var
fi

# Run in the foreground ( do not fork ) - invoking the script from the
# base image will configure the local write_graphite plugin as well.

. /usr/local/bin/runCollectd.sh
