#!/bin/bash
exec >> /var/log/ansible/post_deploy.log
exec 2>&1
set -x

cd `dirname $0`/../
nginx_url=$(tail -n +2 hosts/nginx)

#there are 2 docker images on nginx VM, nginx and side
if [ ! -z "${nginx_url}" ]; then
	#container=`su - ubuntu -c "ssh $nginx_url sudo docker ps -q"`
	processes=`su - ubuntu -c "ssh -o StrictHostKeyChecking=no $nginx_url sudo ps -ef | grep nginx | cut -d' ' -f1 -s"`
	[ -z "${processes}" ] && echo "looks nginx service fail to get start!" && exit -1
	echo "start to refresh nginx on ${nginx_url}"
	su - ubuntu -c "ssh -o StrictHostKeyChecking=no $nginx_url sudo bash -c "/usr/local/bin/cluster-config.sh""
	result=`su - ubuntu -c "ssh -o StrictHostKeyChecking=no $nginx_url sudo supervisorctl update"`
	if [[ $result =~ done ]]; then
		echo "succesfully reload nginx for new es config."
	fi
else
	echo "fail to find the nginx_url to refresh nginx configuration."
	exit -1
fi
