#!/bin/bash
# set -x

if [ $# -lt 1 ]; then
    echo "Usage: export-dashboard.sh <dashboard-key>"
    exit 1
fi

dash_key=$1

if [ -e "../hosts/dashboard_es" ]; then
   elasticsearch_server=$(tail -n 1 ../hosts/dashboard_es)
else
   elasticsearch_server=`cat ../floatings/elasticsearch_http_lb`
fi
graphite_environment=`cat ../group_vars/all | grep graphite_environment:`
space_id=`echo $graphite_environment | cut -d ':' -f2 | cut -d '.' -f1 | tr -d '[[:space:]]'`
env=`echo $graphite_environment | cut -d ':' -f2 | cut -d '.' -f2`

basedir=`cd $(dirname ${BASH_SOURCE[0]}); pwd`

registry=$(cat ../group_vars/all | grep registry: | cut -d' ' -f 2 | tr -d \'\")

image_version=$(cat ../group_vars/versions | grep op_services_dashboards_version | cut -d' ' -f2 | tr -d "'")

image="$registry/op-services-dashboards:$image_version"
sudo docker run --rm ${image} export ${elasticsearch_server} ${space_id} ${env} ${dash_key}

