#!/bin/bash
#set -x

[ $# -lt 1 ] && echo "$0 <role_name> [apt_snapshot | serial] <ucd_deploy>" && exit -1
use_flock="true"
role_name=$1
snapshot=$2
batch_size=$2
ucd_deploy=$3

# No UPDATE_ENABLED in other playbooks, so skip UPDATE_ENABLED in input parameter
function role_update
{
  role=$1
  cluster_num=$2
  serial=$3
  ucd_deploy=$4
  echo "Start to upgrade role: ${role} with serial: ${serial} at [`date`]"  
  /opt/deploy/scripts/config_cluster.sh  $role --cluster-num ${cluster_num} \
  --config-stack false --batch-size ${serial} \
  --dependencies false  --ucd_deploy ${ucd_deploy}>> /var/log/ansible/role_update.log 2>&1
  matched=$(grep -n 'PLAY RECAP' /var/log/ansible/role_update.log  | cut -d : -f1 | tail -1)
   [ -n ${matched} ] && tail -n +${matched} /var/log/ansible/role_update.log
   echo "End to upgrade role: ${role} at [`date`]"
}

#just for collectd and apt_repo role
function ansible_playbook_update
{
    role=$1
    snapshot=$2
    update_enabled=$3
    serial="100%"
    echo "Start to ugprade role: ${role} at [`date`]"    
    ansible-playbook -i hosts/.all ${role}.yml \
    --extra-vars="UPDATE_ENABLED=${update_enabled} apt_repo=${snapshot}  rolling_update_batch_size=${serial}" \
    -vvv  >> /var/log/ansible/role_update.log 2>&1
    matched=$(grep -n 'PLAY RECAP' /var/log/ansible/role_update.log  | cut -d : -f1 | tail -1)
    [ -n ${matched} ] && tail -n +${matched} /var/log/ansible/role_update.log
    echo "End to upgrade role: ${role} at [`date`]"
}

function show_apt_repo
{
    echo "Current apt_repo at [`date`]" 
    ansible  -i /opt/deploy/hosts/.all all -s -a 'cat /etc/apt/sources.list.d/logging.list'
    echo "End apt_repo display at [`date`]"
}

function snapshotVar_update
{
    snapshot=$1
    sed -i -r "s#apt_repo: ".*"#apt_repo: ${snapshot}#g" /opt/deploy/group_vars/all
}
###############################################################################
# Let's start
###############################################################################

# acquire the flock if needed
exec 100>/var/lock/role_update.lock
flock 100

cd /opt/deploy

#es cluster_number
if [ -f "es_clusters" ];
then
    cluster_number=$(cat es_clusters | awk '{print $2}')
else
    cluster_number=1
fi

#ansible serial batch size
[ -z "${batch_size}" ] && batch_size=1

#if snapshot parameter is missing, get that from group_vars
if [ -z "${snapshot}" ];
then
    snapshot=`cat group_vars/all | grep apt_repo | grep -v second_apt_repo | awk '{print $2;}'`
fi

if [ -z "${ucd_deploy}" ]; then
   ucd_deploy="false"
fi

apt_repo_name=`cat group_vars/all | grep apt_repo | grep -v second_apt_repo | awk '{print $2;}'`

if [[ "${role_name}" = "apt_repo" ||  "${role_name}" = "collectd" ||  "${role_name}" = "mt_lsf" ||  "${role_name}" = "es_config" ||  "${role_name}" = "es_retention" ]];
then
    [[ ${snapshot} != logging* ]] && echo "new snapshot name should be started with logging " && exit -1
    if [ "${apt_repo_name}" = "${snapshot}" ];
    then
        ansible_playbook_update ${role_name} ${snapshot} 0
    else
        snapshotVar_update ${snapshot}
        sleep 3
        ansible_playbook_update ${role_name} ${snapshot} 1
    fi
    show_apt_repo
else
    role_update ${role_name} ${cluster_number} ${batch_size} ${ucd_deploy}
fi

# release the flock if needed
flock -u 100
