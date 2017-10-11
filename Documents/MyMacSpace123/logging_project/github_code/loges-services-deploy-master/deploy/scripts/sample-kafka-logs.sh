#!/bin/bash
#
# Sample 10 logs from kafka to see what data is being processed
#
[ "$#" -gt 1 ] && echo "Usage: $0 <cluster_number>" && exit 1

cluster=${1:-1}

kafka_host=$(tail -n 1 /opt/deploy/hosts/kafka)
kafka_url="$kafka_host:9092"

# Check if multi_cluster is enabled
MULTI_TOPICS_ENABLED=$(grep "MULTI_TOPICS_ENABLED" /opt/deploy/group_vars/all | awk -F ": " '{print $2}')

if [[ "$MULTI_TOPICS_ENABLED" -eq 1 ]]; then
    cluster_name=$(grep -m 1 "\b$cluster" /opt/deploy/es_clusters | awk '{print $1}')
    [[ -z "$cluster_name" ]] && echo "Invalid cluster number $cluster" && exit 1
	topic="topic${cluster}-${cluster_name}"
else
        topic="alchemy-logs"
fi

cmd="/opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server $kafka_url --topic $topic --max-messages 10 --consumer.config /opt/kafka/config/command.properties"

ssh -t $kafka_host sudo $cmd

