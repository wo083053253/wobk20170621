#!/bin/bash

script=$(basename $0)

function usage() {
  echo "usage: $script space_id"
  echo "       Shows the logging token for a space"
}

if [[ $# != 1 ]]; then
  usage
  echo "error: exactly one argument expected"
  exit 1
fi

space="${1,,}"
space_pattern="^[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}$"

if [[ ! "$space" =~ $space_pattern ]]; then
  echo "error: space id is not a valid uuid"
  exit 1
fi

es="http://$(cat /opt/deploy/floatings/elasticsearch_http_lb):9200"
index="logging-password"
doctype="pass"

line="$(curl -s "$es/$index/$doctype/$space?pretty" | grep _source )"

if [[ $? != 0 ]]; then
  echo "error: could not fetch token for $space"
  exit 1
fi

token="$(expr "$line" : '.*"\([-0-9a-zA-Z_=]\{40,48\}\)".*')"

if [[ "$token" == "" ]]; then
  echo "error: token not found for $space"
  exit 1
fi

echo "$token"
