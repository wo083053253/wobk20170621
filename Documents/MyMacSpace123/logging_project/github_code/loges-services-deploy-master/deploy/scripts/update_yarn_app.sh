#!/bin/bash

set -eux

jarname="uber-eventgen-spark-1.0.jar"
file="/opt/apps/${jarname}"
logfile="/tmp/spark-submit.log"

rm -f $logfile

if [ -f  $file  ] ;  then
  echo "copy over latest app."
  mv $file ${file}.old
fi

docker cp eventgen_binaries:/opt/apps/${jarname}  /tmp/apps

chown  -R stack:stack /tmp/apps/*

mv /tmp/apps/* /opt/apps/

app_id=`/opt/hadoop/bin/yarn application -list | grep application_ | awk '{print $1}'`

if [ ! -z $app_id ]; then
  echo "Found App... Killing it..."
  # new way to stop the application
  sudo supervisorctl stop eventgen-daemon
  /opt/hadoop/bin/yarn application -kill $app_id
fi

sudo -u stack /opt/hadoop/bin/hadoop fs -rm -R -f /user/spark/checkpoint/*

echo "Starting Eventgen Daemon and Spark App..."

if [ -f /opt/hadoop/sbin/eventgen-daemon.sh ]; then
   # new way to start the application
   sudo supervisorctl start eventgen-daemon
   sleep 60
else
   sudo -u stack /opt/spark/bin/spark-submit --class com.ibm.alchemy.eventgen.EventGenMetrics --files /opt/apps/app.conf,/opt/apps/jaas.conf,/opt/spark/conf/log4j.properties --master yarn-cluster /opt/apps/uber-eventgen-spark-1.0.jar app.conf > $logfile 2>&1 &
   x=$!
   sleep 60
   disown $x
   pid=`ps -ef | grep spark-submit | head -n 1 | awk '{print $2}'`
   kill $pid
fi

/opt/hadoop/bin/yarn application -list

echo "Done starting..."

