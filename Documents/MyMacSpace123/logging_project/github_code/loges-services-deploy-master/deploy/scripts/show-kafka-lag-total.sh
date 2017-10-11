#!/bin/bash
#
#
[ "$#" -gt 1 ] && echo "Usage: $0 <group_name>" && exit 1

group=${1:-logstash}

kafka_host=$(tail -n 1 /opt/deploy/hosts/kafka)
kafka_url="$kafka_host:9092"

cmd="/opt/kafka/bin/kafka-consumer-groups.sh --describe --group $group --bootstrap-server $kafka_url --command-config /opt/kafka/config/command.properties"
cginfo=$(ssh $kafka_host sudo $cmd)

if [ $? -ne 0 ]
then
  echo "Failed to get the info of the group $group"
  exit 1
fi

#TOPIC PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG  CONSUMER-ID HOST CLIENT-ID
#Sum up the value "LAG" column (column 5) to get the total lag
total=$( echo "$cginfo" | sed '/^ *$/d' | tail -n +2 |  awk 'NR > 0 { sum += $5 } END { print sum }')

echo $total
