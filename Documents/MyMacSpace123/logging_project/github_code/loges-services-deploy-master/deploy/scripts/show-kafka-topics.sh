#!/bin/bash
#
#
for i in $(tail -n +2 /opt/deploy/hosts/zookeeper); do
    zookeeper_url="$zookeeper_url,""$i:2181"
done
zookeeper_url="${zookeeper_url/,/}"

host=$(tail -n 1 /opt/deploy/hosts/kafka)

cmd="/opt/kafka/bin/kafka-topics.sh --describe --zookeeper $zookeeper_url"

echo ssh -t $host sudo $cmd
ssh -t $host sudo $cmd

