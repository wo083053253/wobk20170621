#!/bin/bash
set -e

{
    LOG_FILE="/var/log/provisioning-tests.log"
    STATSD_CONF_FILE="/etc/collectd/collectd.conf.d/statsd.conf"
    LOGROTATE_CONFIG="/etc/logrotate.d/provisioning-tests"

    export MONITOR_SPACE="monitor-space-1"
    [ -z "$LOGMET_LOGIN_ENDPOINT" ]           && export LOGMET_LOGIN_ENDPOINT="https://$LOGMET_API_SERVER/login"
    [ -z "$PROVISION_TOKEN_RESPONSE_THRESH" ] && export PROVISION_TOKEN_RESPONSE_THRESH=50 #seconds
    [ -z "$LOGMET_REPO_ENDPOINT" ]            && export LOGMET_REPO_ENDPOINT="https://downloads.opvis.bluemix.net:5443"
    [ -z "$PROVISION_REPO_RESPONSE_THRESH" ]  && export PROVISION_REPO_RESPONSE_THRESH=50 #seconds
    [ -z "$PROVISION_TEST_FREQUENCY" ]        && export PROVISION_TEST_FREQUENCY="60"
    [ -z "$PROVISION_LOGMET_LOG_LEVEL" ]      && export PROVISION_LOGMET_LOG_LEVEL="WARN"

    sed -i "s|REPLACE_STATSD_HOST|$STATSD_HOST|g" $STATSD_CONF_FILE
    sed -i "s|REPLACE_STATSD_PORT|$STATSD_PORT|g" $STATSD_CONF_FILE

    echo "     - - - - - - - - - - - -" >> $LOG_FILE
    echo "BLUEMIX_USERID:                   $BLUEMIX_USERID" >> $LOG_FILE
    echo "BLUEMIX_PASSWORD LENGTH:          ${#BLUEMIX_PASSWORD}" >> $LOG_FILE
    echo "MONITOR_SPACE:                    $MONITOR_SPACE" >> $LOG_FILE
    echo "BLUEMIX_ORG_NAME:                 $BLUEMIX_ORG_NAME" >> $LOG_FILE
    echo "LOGMET_LOGIN_ENDPOINT:            $LOGMET_LOGIN_ENDPOINT" >> $LOG_FILE
    echo "PROVISION_TOKEN_RESPONSE_THRESH:  $PROVISION_TOKEN_RESPONSE_THRESH" >> $LOG_FILE
    echo "LOGMET_REPO_ENDPOINT:             $LOGMET_REPO_ENDPOINT" >> $LOG_FILE
    echo "PROVISION_REPO_RESPONSE_THRESH:   $PROVISION_REPO_RESPONSE_THRESH" >> $LOG_FILE
    echo "STATSD_HOST:                      $STATSD_HOST" >> $LOG_FILE
    echo "STATSD_PORT:                      $STATSD_PORT" >> $LOG_FILE
    echo "PROVISION_TEST_FREQUENCY:         $PROVISION_TEST_FREQUENCY" >> $LOG_FILE
    echo "PROVISION_LOGMET_LOG_LEVEL:       $PROVISION_LOGMET_LOG_LEVEL" >> $LOG_FILE
    echo "Starting logmet provisioning tests at $(date)" >> $LOG_FILE
    
    python3 /opt/provision-logmet/provisioning-tests.py -f $LOG_FILE -l $PROVISION_LOGMET_LOG_LEVEL
    flock -u 100
} 100<>/var/lock/logmet-provisioning.lock

