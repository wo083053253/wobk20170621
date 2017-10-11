#!/bin/bash
#
# script to modify an environment so that the current elasticsearch
# cluster is the first cluster in a multicluster configuration
#

# update the hosts file for logstash and elasticsearch to match the new naming schema
mv /opt/deploy/hosts/logstash /opt/deploy/hosts/logstash_1
mv /opt/deploy/hosts/elasticsearch_data_hot /opt/deploy/hosts/elasticsearch_data_hot_1
mv /opt/deploy/hosts/elasticsearch_data_warm /opt/deploy/hosts/elasticsearch_data_warm_1
mv /opt/deploy/hosts/elasticsearch_http /opt/deploy/hosts/elasticsearch_http_1
mv /opt/deploy/hosts/elasticsearch_master /opt/deploy/hosts/elasticsearch_master_1
mv /opt/deploy/hosts/logstash_fastforwarder /opt/deploy/hosts/logstash_fastforwarder_1
# to keep files with the old naming schema
# cp /opt/deploy/hosts/logstash /opt/deploy/hosts/logstash_1
# cp /opt/deploy/hosts/elasticsearch_data_hot /opt/deploy/hosts/elasticsearch_data_hot_1
# cp /opt/deploy/hosts/elasticsearch_data_warm /opt/deploy/hosts/elasticsearch_data_warm_1
# cp /opt/deploy/hosts/elasticsearch_http /opt/deploy/hosts/elasticsearch_http_1
# cp /opt/deploy/hosts/elasticsearch_master /opt/deploy/hosts/elasticsearch_master_1
