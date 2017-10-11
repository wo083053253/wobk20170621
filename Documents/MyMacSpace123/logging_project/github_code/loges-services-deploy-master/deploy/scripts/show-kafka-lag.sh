#!/bin/bash
#
#
[ "$#" -gt 1 ] && echo "Usage: $0 <group_name>" && exit 1

group=${1:-logstash}

kafka_host=$(tail -n 1 /opt/deploy/hosts/kafka)
kafka_url="$kafka_host:9092"


cmd="/opt/kafka/bin/kafka-consumer-groups.sh --describe --group $group --bootstrap-server $kafka_url --command-config /opt/kafka/config/command.properties"
ssh -t $kafka_host sudo $cmd
