#!/bin/bash

#ip address of the system
#role name

ip=$1
role=$2

broker_id=0
cnt=0

    for i in $(tail -n +2 /opt/deploy/hosts/$role); do
        if [ "$ip" == "$i" ]; then
            broker_id=$cnt
        fi
        let cnt=$cnt+1
    done

echo "$broker_id"
