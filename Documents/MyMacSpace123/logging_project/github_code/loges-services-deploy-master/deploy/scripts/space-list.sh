#!/bin/bash

script=$(basename $0)

function usage() {
  echo "usage: $script"
  echo "       Lists all the space ids that have logging tokens"
}

if [[ $# != 0 ]]; then
  usage
  echo "error: no arguments expected"
  exit 1
fi

es="http://$(cat /opt/deploy/floatings/elasticsearch_http_lb):9200"
index="logging-password"
doctype="pass"

line="$(curl -s "$es/$index/$doctype/_count?pretty" | grep count )"

if [[ $? != 0 ]]; then
  echo "error: could not fetch token count"
  exit 1
fi

count="$(expr "$line" : '.* \([0-9]\+\),.*')"

if [[ "$count" == "" ]]; then
  echo "error: no token count found"
  exit 1
fi

space_pattern='.*"\([-0-9a-f]\+\)".*'

curl -s "$es/$index/$doctype/_search?pretty&size=$count" | grep _id | while read line; do
  space=$(expr "$line" : "$space_pattern")
  if [[ ! -z "$space" ]]; then
    echo $space
  fi
done
