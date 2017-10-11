#!/bin/bash

set -x

cd /opt/deploy

client_id=`cat group_vars/eventgen_rest_servers | grep client_id | awk '{print $2;}'`
client_secret=`cat group_vars/eventgen_rest_servers | grep client_secret | awk '{print $2;}'`
uaa_token_url=`cat group_vars/eventgen_rest_servers | grep uaa_token_url | awk '{print $2;}'`

yarn_master_ip=`tail -n +2 hosts/yarn_master`

if [ -e floatings/nginx_lb ]; then
  logmet_external_ip=`cat floatings/nginx_lb`
else 
  logmet_external_ip=`cat floatings/nginx`
fi
carbonrelay_lb_ip=`cat floatings/carbonrelay_lb`

dashboard_proxy_dev=`cat group_vars/all | grep dashboard_proxy | awk '{print $2;}'`

logs_ip=`cat floatings/mtlumberjack_lb`
metrics_ip=`cat floatings/mtgraphite_lb`

eventgen_user=`cat group_vars/all_eventgen | grep eventgen_username | awk '{print $2;}'`
eventgen_userpwd=`cat group_vars/all_eventgen | grep eventgen_userpwd | awk '{print $2;}'`
eventgen_space_name=`cat group_vars/all_eventgen | grep eventgen_space_name | awk '{print $2;}'`
eventgen_org_name=`cat group_vars/all_eventgen | grep eventgen_org_name | awk '{print $2;}'`

eventgen_space_id=`cat group_vars/all_eventgen | grep eventgen_space_id | awk '{print $2;}'`
eventgen_login_token=`cat group_vars/all_eventgen | grep eventgen_login_token | awk '{print $2;}'`
eventgen_metrics_infix=`cat group_vars/all_eventgen | grep eventgen_metrics_infix | awk '{print $2;}'`
eventgen_metrics_cname=`cat group_vars/all_eventgen | grep eventgen_metrics_cname | awk '{print $2;}'`
eventgen_metrics_hostname=`cat group_vars/all | grep metrics_hostname | awk '{print $2;}'`

if [ -z $eventgen_space_id ] || [  -z $eventgen_login_token ] ; then
    login_response=`curl -s -k -XPOST -d "user=${eventgen_user}&passwd=${eventgen_userpwd}&space=${eventgen_space_name}&organization=${eventgen_org_name}" https://${logmet_external_ip}/login`
    eventgen_login_token=`echo ${login_response} | python -c 'import sys, json; print json.load(sys.stdin)["logging_token"]'`
    eventgen_space_id=`echo ${login_response} | python -c 'import sys, json; print json.load(sys.stdin)["space_id"]'`
fi

if [ -z $eventgen_login_token ]; then
   if [ -e files/yarn/eventgen_login_token ]; then
     eventgen_login_token=`cat files/yarn/eventgen_login_token | grep eventgen_login_token | awk '{print $2;}'`
     eventgen_space_id=`cat files/yarn/eventgen_space_id | grep eventgen_space_id | awk '{print $2;}'`
   fi
   if [ -z $eventgen_login_token ]; then
     eventgen_login_token="N_A_CHECK_CURL_COMMAND"
   fi
fi

logmet_environment=`cat group_vars/all | grep logmet_environment | awk '{print $2;}'`

if [ "$logmet_environment" = "dev" ]; then
    eventgen_log_space_id=$eventgen_space_id
    eventgen_log_login_token=$eventgen_login_token
    eventgen_log_hostname=`cat group_vars/all | grep logs_hostname | awk '{print $2;}'`
else
    eventgen_log_space_id=`cat group_vars/all_eventgen | grep eventgen_log_space_id | awk '{print $2;}'`
    eventgen_log_login_token=`cat group_vars/all_eventgen | grep eventgen_log_login_token | awk '{print $2;}'`
    eventgen_log_hostname=`cat group_vars/all_eventgen | grep eventgen_log_hostname | awk '{print $2;}'`
fi

ansible-playbook -vvv -i hosts/monitor cflogin.yml --extra-vars="cf_auth_refresh_interval=360" >> /var/log/ansible/playbook.log
ansible-playbook -vvv -i hosts/monitor cfConfigCopy.yml  --extra-vars="cluster=monitor cf_auth_refresh_interval=360">> /var/log/ansible/playbook.log
ansible-playbook -vvv -i /opt/deploy/hosts/monitor --extra-vars "client_id=${client_id} client_secret=${client_secret} uaa_token_url=${uaa_token_url} yarn_master_ip=${yarn_master_ip} carbonrelay_lb_ip=${carbonrelay_lb_ip} eventgen_monitor_login_token=${eventgen_login_token} eventgen_monitor_space_id=${eventgen_space_id}  eventgen_log_login_token=${eventgen_log_login_token} eventgen_log_space_id=${eventgen_log_space_id} eventgen_log_hostname=${eventgen_log_hostname} logmet_environment=${logmet_environment} eventgen_user=${eventgen_user} eventgen_userpwd=${eventgen_userpwd} eventgen_space_name=${eventgen_space_name} eventgen_org_name=${eventgen_org_name} eventgen_metrics_infix=${eventgen_metrics_infix} logs_ip=${logs_ip} metrics_ip=${metrics_ip} logmet_external_ip=${logmet_external_ip} eventgen_metrics_cname=${eventgen_metrics_cname} dashboard_proxy_dev=${dashboard_proxy_dev} rolling_update_batch_size=1 " /opt/deploy/monitor_eventgen_java.yml >> /var/log/ansible/playbook.log

