#!/bin/bash

# This script is used to verify a redis/tenantinfo node is up/connected before configuring 
# the next node so we avoid taking down the master and slaves all together.
TARGET=$1
MASTER=$2

if [ ! -e /usr/bin/redis-cli ]; then
  apt-get -y install redis-tools
fi

IS_MASTER=false
if [[ ${TARGET} == ${MASTER} ]]; then
  IS_MASTER=true
fi

IS_UP=false
ATTEMPTS="0"
while [ ${IS_UP} == "false" ] && [ ${ATTEMPTS} -lt 3 ]; do
  # redis-cli will attempt to connect for up to 120 seconds
  if [[ ${IS_MASTER} == "true" ]]; then
    FOUND=`redis-cli -h ${TARGET} info replication | grep "role:master" | wc -l`
  else
    FOUND=`redis-cli -h ${TARGET} info replication | grep "master_link_status:up"|wc -l`
  fi
  if [[ ${FOUND} == "1" ]]; then
    IS_UP=true
  else
    sleep 5
  fi
  ATTEMPTS=$[$ATTEMPTS+1]
done

if [ ${IS_UP} != "true" ]; then
  echo "Redis node ${TARGET} still not up"
else
  echo "Redis node ${TARGET} is up and healthy"
fi
