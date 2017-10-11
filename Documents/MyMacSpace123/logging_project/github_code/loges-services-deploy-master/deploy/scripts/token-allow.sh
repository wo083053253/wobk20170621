#!/bin/bash

script=$(basename $0)

function usage() {
  echo "usage: $script space_id"
  echo "       Unblocks the logging token for a space by removing the prefix 'invalid-'"
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

if [[ ${#token} == 40 ]]; then
  echo "token is already unblocked"
  exit 0
fi

token="${token:8}"

./token-set.sh "$space" "$token"

if [[ $? != 0 ]]; then
  echo "error updating token for $space"
  exit 1
fi

echo "token for $space unblocked: ${token:0:12}..."
