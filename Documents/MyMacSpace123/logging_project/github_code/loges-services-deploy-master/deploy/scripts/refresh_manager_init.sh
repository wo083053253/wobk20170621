#!/bin/bash
currentdir=`pwd`
basedir=`cd $(dirname ${BASH_SOURCE[0]}); pwd`
if readlink $basedir &> /dev/null; then
    basedir=`cd $(readlink ${basedir}); pwd`
fi
[ -d $currentdir/env ] || ln -s $basedir $currentdir/env
cd $currentdir/pkg
tar cfhz - * | base64 > $currentdir/manager_init_data
