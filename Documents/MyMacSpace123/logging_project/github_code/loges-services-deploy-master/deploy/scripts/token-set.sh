#!/bin/bash

script=$(basename $0)

function usage() {
  echo "usage: $script space_id token"
  echo "       Sets the logging token for a space"
}

if [[ $# != 2 ]]; then
  usage
  echo "error: exactly two argument expected"
  exit 1
fi

space="${1,,}"
space_pattern="^[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}$"

if [[ ! "$space" =~ $space_pattern ]]; then
  echo "error: space id is not a valid uuid"
  exit 1
fi

token="$2"
token_pattern="^[-0-9a-zA-Z_=]{40,48}$"

if [[ ${#token} != 40 && ${#token} != 48 ]]; then
  echo "error: token must be either 40 or 48 characters long"
  exit 1
fi

if [[ ${#token} == 48 && ${token:0:8} != "invalid-" ]]; then
  echo "error: a blocked token of length 48 must begin with 'invalid-': ${token:0:12}"
  exit 1
fi

es="http://$(cat /opt/deploy/floatings/elasticsearch_http_lb):9200"
index="logging-password"
doctype="pass"

doc='{"doc":{"logging-password":"'$token'"}}'

curl -s -XPOST -H 'Content-Type: application/json' -d "$doc" "$es/$index/$doctype/$space/_update"

if [[ $? != 0 ]]; then
  echo "error: could not update token for $space"
  exit 1
fi

echo "token for $space is now: $token"
