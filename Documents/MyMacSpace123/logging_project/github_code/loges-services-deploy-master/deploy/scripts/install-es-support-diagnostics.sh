#!/bin/bash
#set -x

# Install the elasticsearch diagnostics utility into each elasticsearch master node
#
container_name=elasticsearch


for i in $(cat /opt/deploy/hosts/elasticsearch_master); do
    if [[ $i != *"_servers"* ]]; then
        ssh $i sudo docker exec $container_name wget --directory-prefix=/tmp https://github.com/elastic/elasticsearch-support-diagnostics/releases/download/2.0.2/support-diagnostics-2.0.2-dist.zip

        ssh $i sudo docker exec $container_name apt-get update
        ssh $i sudo docker exec $container_name apt-get install unzip
        ssh $i sudo docker exec $container_name unzip /tmp/support-diagnostics-2.0.2-dist.zip -d /tmp
        ssh $i sudo docker exec $container_name rm /tmp/support-diagnostics-2.0.2-dist.zip
    fi
done