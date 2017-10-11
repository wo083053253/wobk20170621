#!/bin/bash
#set -x

if [ $# -lt 3 ]; then
    echo "Usage : collect_container_log.sh role_name container_name log_path"
    exit -1
fi

cd `dirname $0`/../

role=$1
container_name=$2
log_path=$3

output=/tmp/${role}_logs

timestamp=`date`
echo $timestamp >> $output

for i in $(cat hosts/$role); do
    if [[ $i != *"_servers"* ]]; then
        echo "  " >> $output
        echo "log from $i" >> $output
        ssh $i sudo docker exec $container_name tail $log_path >> $output
    fi
done

