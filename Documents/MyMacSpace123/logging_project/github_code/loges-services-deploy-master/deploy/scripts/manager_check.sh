#!/bin/bash
function check_node
{
    address=$1
    result=`ssh $address echo pong`
    [ "$result" = "pong" ] && return 0
    return 1
}

function rebuild_node
{
    node=$1
    restart_url=$2
    curl -k -i -XPOST "$restart_url"
    mv -f $node $(dirname ${node})/.$(basename ${node})
}

function rebuild_hosts
{
    address=$1
    flock 100
    for role in ${basedir}/hosts/*; do
        [ -f "$role" ] || continue
        sed -i "/^${address//./\\.}$/d" $role
    done
    flock -u 100
} 100<>/tmp/register.lock

basedir=`cd $(dirname ${BASH_SOURCE[0]})/..; pwd`
for node in $basedir/nodes/*; do
    [ -f "$node" ] || continue
    source $node
    check_node $address || rebuild_node $node $restart_url
    [ -f "$node" ] || rebuild_hosts $address
done
