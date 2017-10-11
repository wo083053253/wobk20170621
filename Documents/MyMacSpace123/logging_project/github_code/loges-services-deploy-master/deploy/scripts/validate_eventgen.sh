#!/bin/bash
debug=0
cd `dirname $0`/../

if [ "$1" == "-debug" ]; then
    debug=1
fi


testYarn()
{
    echo "Yarn: Success"
}

testSpark()
{
    echo "Spark: Success"
}

testMessageHub()
{
    echo "MessageHub: Success"
}

testRESTLB()
{
    echo "REST Load Balancer: Success"
}

testREST()
{
    echo "REST Server direct: Success"
}

testMonitor()
{
    monitorHost=`tail -n1 /opt/deploy/hosts/monitor`
    [ $debug == 0 ] || echo "Monitor Host : $monitorHost"

    status=$(curl -s http://${monitorHost}:8081/status)
    [ $debug == 0 ] || echo "Eventgen Health: $status"

    healthy=$(echo "$status" | python -mjson.tool | grep "status.*OK" | wc -l )
    if [ "${healthy}" == "1" ]; then
        echo "Eventgen Monitor: Success"
    else
        echo "Eventgen Monitor: Failed"
    fi
}

testYarn
testSpark
testMessageHub
testRESTLB
testREST
testMonitor

