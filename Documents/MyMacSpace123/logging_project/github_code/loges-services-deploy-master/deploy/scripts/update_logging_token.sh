#!/bin/bash
#Using tenantinfo API to get logging token
#Put nginx-lb and token to group_vars/all
set -x
exec >> /var/log/ansible/post_deploy.log
exec 2>&1

#install jq
apt-get install -y jq

base_root=/opt/deploy
cd ${base_root}

client_auth=`cat group_vars/all | grep -i tenantinfo_client_auth | awk '{print $2;}'`
space_id=`cat group_vars/all | grep -i sidecar_target_space_id | awk '{print $2;}'`

[ ! -f "hosts/multiserver_lb" ] && echo "Fail to locate the multiserver_lb host file" && exit -1
[ ! -f "hosts/nginx_lb" ] && echo "Fail to locate the nginx_lb host file" && exit -1

tenantinfo_server=$(tail -n 1 hosts/multiserver_lb)

#get one nginx_lb
internal_nginx_lb_ip="$(tail -n 1 hosts/nginx_lb)"


cat << EOF > ${base_root}/get_token.json
{
    "client-auth":"${client_auth}",
    "space-id":"${space_id}"
}
EOF

url="https://${tenantinfo_server}:9099/loggingpassword"
logging_token=$(curl ${url} -k -X GET -d @get_token.json | jq .'["logging-password"]' |sed 's/[ ",;]//g')

echo "sidecar_target_token: ${logging_token}" >>  ${base_root}/group_vars/all
echo "internal_nginx_lb_ip: ${internal_nginx_lb_ip}" >> ${base_root}/group_vars/all
