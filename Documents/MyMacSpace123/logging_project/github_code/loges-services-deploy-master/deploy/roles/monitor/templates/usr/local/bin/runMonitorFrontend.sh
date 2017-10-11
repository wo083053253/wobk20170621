#!/bin/bash
#
# Start the monitor frontend application within a docker container 
#
# This application runs the cherrypie http server used as the frontend to
# the monitor application
#
# The server.py requires a configuration file in the same directory
#   1) server.conf - configures the ports 
/usr/local/bin/overrideHosts.sh

if [ -f /certs/DigiCertCA.pem ]
then
  # copy DigiCertCA with .crt extention
  cp /certs/DigiCertCA.pem /usr/local/share/ca-certificates/DigiCertCA.crt
    
  # run update ca-certificates
  update-ca-certificates
fi

cd /opt/monitor

echo "waiting for monitor backend to start first."

maxTry=10
count=1
monitor_backend_found=`ps -ef | grep -v "grep" | grep -w "python monitors.py"`
while [ -z "$monitor_backend_found" ]; do
    if [ $count -le $maxTry ]; then
        count=$[${count}+1]
        sleep 10
    else
        echo "Time out on waiting for monitor backend to start."
        exit 1
    fi
    monitor_backend_found=`ps -ef | grep -v "grep" | grep -w "python monitors.py"`
done
# Start the server process 
echo "Starting the server.py python process - Frontend Process"

python server.py

echo "server.py exiting"
