#!/bin/bash

script=$(basename $0)

function usage() {
  echo "usage: $script space_id"
  echo "       Blocks the logging token for a space by prefixing it with 'invalid-'"
}

if [[ $# != 1 ]]; then
  usage
  echo "error: exactly one argument expected"
  exit 1
fi

space="$1"

token="$( ./token-get.sh "$space" )"

if [[ $? != 0 ]]; then
  echo "error fetching token for $space"
  exit 1
fi

if [[ ${#token} == 48 && ${token:0:8} == "invalid-" ]]; then
  echo "token for $space is already blocked: ${token:0:12}..."
  exit 0
fi

token="invalid-$token"

./token-set.sh "$space" "$token"

if [[ $? != 0 ]]; then
  echo "error updating token for $space"
  exit 1
fi

echo "token for $space has been blocked: ${token:0:12}..."

