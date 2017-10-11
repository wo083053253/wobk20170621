#!/bin/bash

curl -XPOST  localhost:9200/_flush/synced

curl -XPUT localhost:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.node_concurrent_recoveries" : "5" } }'

curl -XPUT localhost:9200/_cluster/settings -d '{ "transient" : { "cluster.routing.allocation.cluster_concurrent_rebalance" : "0" } }'

curl -XPUT localhost:9200/_all/_settings -d '{ "settings" : { "index.unassigned.node_left.delayed_timeout": "120m" } }'
