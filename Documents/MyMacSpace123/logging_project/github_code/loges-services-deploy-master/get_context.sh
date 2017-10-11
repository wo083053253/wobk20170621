#!/bin/bash

cd $(dirname $BASH_SOURCE[0])/heat

[ $# -lt 1 ] && echo "./get_context.sh <privatekeypath>" && exit -1
private_key=$1

mkdir -p data
cp $private_key data/private_key
