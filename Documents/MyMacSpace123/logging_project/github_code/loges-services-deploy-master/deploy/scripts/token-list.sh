#!/bin/bash

script=$(basename $0)

function usage() {
  echo "usage: $script [separator]"
  echo "       Lists all space ids and their logging tokens"
}

if [[ $# > 1 ]]; then
  usage
  echo "error: too many arguments"
  exit 1
fi

sep="${1:- : }"

./space-list.sh | while read space; do
  token=$(./token-get.sh $space)
  echo "$space$sep$token"
done
