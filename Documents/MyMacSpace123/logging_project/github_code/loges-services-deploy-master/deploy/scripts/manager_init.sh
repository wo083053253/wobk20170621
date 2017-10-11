#!/bin/bash
set -x
addr=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
deploy_root=/opt/deploy
echo "Start at [`date`]"
#assign /opt/deploy with ubuntu user, ensure other nodes can write files to manager node
chown -R ubuntu:ubuntu ${deploy_root}
cd ${deploy_root}

stack=$1
hname=$2
environment=$3
apt_repo=$4

[ -z $stack ] && exit 0
[ -z $hname ] && exit 0
[ -z $environment ] && environment=dev
[ -z $apt_repo ] && apt_repo=logging

addr=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
hname=$hname-${addr##*.}

mkdir hosts nodes floatings vips
chmod -R a+r .
chmod a+x scripts/*.sh

#update hosts
hostname=`hostname -s`
echo "${addr}  ${hostname}" >> /etc/hosts

su - ubuntu -c "ssh-keyscan -H $addr >> /home/ubuntu/.ssh/known_hosts"

#decrypt all files which are encrypted
grep -l -r '^$ANSIBLE_VAULT;1.1;AES256' ${deploy_root} |
   while read file; do
      ansible-vault --vault-password-file ${deploy_root}/.vault.pass decrypt $file;
   done

#update ${environment} credentials
chmod +x ${deploy_root}/operation/environments/common/update_credential.sh
${deploy_root}/operation/environments/common/update_credential.sh ${environment}

#copy operation/environments/
cp -rf ${deploy_root}/operation/environments/${environment}/heat/*  ${deploy_root}
cp -rf ${deploy_root}/operation/environments/common/aws ${deploy_root}/files

#copy sensu group all
sensu_env=${environment}
if [[ "${sensu_env}" = "prod-ibm5" || "${sensu_env}" = "dal09-prod" ]]; then
    cp -f ${deploy_root}/operation/environments/sensu/all.prod ${deploy_root}/sensu-checks/ansible/group_vars/all
elif [[ "${sensu_env}" = "syd01-prod" || "${sensu_env}" = "syd01-ibm" ]]; then
    cp -f ${deploy_root}/operation/environments/sensu/all.syd01-prod ${deploy_root}/sensu-checks/ansible/group_vars/all
else
    cp -f ${deploy_root}/operation/environments/sensu/all.stage1 ${deploy_root}/sensu-checks/ansible/group_vars/all
fi

sed -i "s/REPLACE_SUBSCRIPTION/${stack}/g" ${deploy_root}/sensu-checks/ansible/group_vars/all

#ansible group vars
sed -i "s/REPLACE_STACK_NAME/${stack}/g" ${deploy_root}/group_vars/all
sed -i "s/REPLACE_APT_REPO/${apt_repo}/g" ${deploy_root}/group_vars/all
if [ -e ${deploy_root}/carbonrelay ]; then
    metrics_host=`cat ${deploy_root}/carbonrelay`
    sed -i -r "s/carbonrelay/$metrics_host/" ${deploy_root}/group_vars/all
fi

echo "MANAGER_IP: ${addr}" >> ${deploy_root}/group_vars/all

#add deploy_environment as upgrade tag, let us know env is dev or edge.
echo "deploy_environment: ${environment}" >> ${deploy_root}/group_vars/all

printf "[manager_servers]\n${addr}\n" > ${deploy_root}/hosts/manager
printf "address='${addr}'\n" > ${deploy_root}/nodes/${hname}

#add kafka zookeeper initmanager IPs to known_hosts
if [ -f "${deploy_root}/hosts/kafka" ]; then
    for i in $(tail -n +2 ${deploy_root}/hosts/kafka); do
        su - ubuntu -c "ssh-keyscan -H $i >> /home/ubuntu/.ssh/known_hosts"
    done
fi

if [ -f "${deploy_root}/hosts/zookeeper" ]; then
    for i in $(tail -n +2 ${deploy_root}/hosts/zookeeper); do
        su - ubuntu -c "ssh-keyscan -H $i >> /home/ubuntu/.ssh/known_hosts"
    done
fi

#if [ -f "${deploy_root}/hosts/initmanager" ]; then
#    for i in $(tail -n +2 ${deploy_root}/hosts/initmanager); do
#        su - ubuntu -c "ssh-keyscan -H $i >> /home/ubuntu/.ssh/known_hosts"
#    done
#fi

chown -R ubuntu:ubuntu /home/ubuntu/.ssh
mkdir -p /var/log/ansible
touch /var/log/ansible/playbook.log
chown -R ubuntu:ubuntu ${deploy_root}
chown -R ubuntu:ubuntu /var/log/ansible

echo "End at [`date`]"
