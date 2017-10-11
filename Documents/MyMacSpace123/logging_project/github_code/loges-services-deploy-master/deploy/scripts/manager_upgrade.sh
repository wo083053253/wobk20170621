#!/bin/bash
set -x
# 1. backup current /opt/deploy folder to new folder under /opt directory
# 2. get some variables from /opt/deploy/group_vars/all
# 3. run apt-get update and apt-get install services-deploy
# 4. rerun manager_init.sh and update_logging_token.sh
# 5. pick up some vars from original group_vars/all to new group_vars/all
# 6. copy some files from origin /opt/deploy to new /opt/deploy

uuid=`date +%Y%m%d%H%M%S`
deploy_root=/opt/deploy
original_deploy_root=/opt/deploy_${uuid}
cp -rf ${deploy_root} ${original_deploy_root}
mv /var/log/ansible /var/log/ansible_${uuid}

stack=`cat ${deploy_root}/group_vars/all | grep STACK_NAME | awk '{print $2;}'`
hname=`hostname`

#get environment from deploy_environment variable, if deploy_environment is not set, get from logmet_environment
environment=`cat ${deploy_root}/group_vars/all | grep deploy_environment | awk '{print $2;}'`
[ -z "$environment" ] && environment=`cat ${deploy_root}/group_vars/all | grep logmet_environment | awk '{print $2;}'`

apt_repo=`cat ${deploy_root}/group_vars/all | grep apt_repo | awk '{print $2;}'`
mtlumberjack_lb_ip=`cat ${deploy_root}/group_vars/all | grep mtlumberjack_lb_ip | awk '{print $2;}'`
db_global=`cat ${deploy_root}/group_vars/all | grep DB_GLOBAL |tail -1 | awk '{print $2;}'`

if [ -z $mtlumberjack_lb_ip ]; then
    mtlumberjack_lb_ip="$(tail -n 1 ${deploy_root}/hosts/mtlumberjack_lb)"
fi

apt-get update && apt-get install loges-services-deploy -y

cp -rf ${original_deploy_root}/carbonrelay ${deploy_root}/
cp -rf ${original_deploy_root}/hosts ${deploy_root}/
cp -rf ${original_deploy_root}/nodes ${deploy_root}/
cp -rf ${original_deploy_root}/vips ${deploy_root}/

${deploy_root}/scripts/manager_init.sh $stack $hname $environment $apt_repo

echo "mtlumberjack_lb_ip: $mtlumberjack_lb_ip" >> /opt/deploy/group_vars/all

if [ -z $db_global ]; then
    echo "DB_GLOBAL: 0" >> /opt/deploy/group_vars/all
else
    echo "DB_GLOBAL: $db_global" >> /opt/deploy/group_vars/all
fi

${deploy_root}/scripts/update_logging_token.sh
