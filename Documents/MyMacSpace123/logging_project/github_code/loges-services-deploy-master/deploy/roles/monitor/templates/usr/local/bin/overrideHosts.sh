#!/bin/bash
# Change hosts endpoints if they are remapped
#
# In the /op-services-deploy/logmet/pkg/scripts/extra_vars.sh,
# $IP_OVERRIDE_LOGS, $IP_OVERRIDE_METRICS and $IP_OVERRIDE_API are being
# decided. In production environment, these three vars will be empty ""
# In dev/prestage/staging, these vars will be remapped to emulate the prod env
LOCK_FILE=/var/run/overrideHosts.lock

while [ -e $LOCK_FILE ]
do
    sleep 1
done

if grep -iFq ".bluemix.net" /etc/hosts; then
    echo "Override already performed. Exiting"
else
    if mkdir $LOCK_FILE 2>/dev/null; then
        echo "Executing override script now!"
        if ! [ -z "$IP_OVERRIDE_LOGS" ]; then
            echo $IP_OVERRIDE_LOGS $LOGS_DATA_COLLECTION_SERVER >> /etc/hosts
            echo "Performed Log override"
        fi

        if ! [ -z "$IP_OVERRIDE_METRICS" ]; then
            echo $IP_OVERRIDE_METRICS $METRICS_DATA_COLLECTION_SERVER >> /etc/hosts
            echo "Performed Metrics override"
        fi

        if ! [ -z "$IP_OVERRIDE_API" ]; then
            echo $IP_OVERRIDE_API $LOGMET_API_SERVER >> /etc/hosts
            echo "Performed API override"
        fi
        echo "Override script execution finished!"
        rm -rf $LOCK_FILE
        echo $? " is the rm exit code"
    fi
fi
