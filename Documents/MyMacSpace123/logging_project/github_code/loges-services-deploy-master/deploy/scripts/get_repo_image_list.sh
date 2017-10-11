#!/bin/bash
# update version config file verions under group_var with the specified component name and tag
set -x

repo_image_list_file=$1
env=$2
credDir=$3

# try bluebox local registry first
ping -c 2 registry.bluebox.net
return_code=$?
if [ $return_code -eq 0  ]; then
    ssh -i /home/stack/.ssh/id_rsa stack@registry.bluebox.net cf ic images > $repo_image_list_file
    login_required=`cat $repo_image_list_file | grep "Not logged in" | wc -l`
    if [ $login_required -eq 1 ]; then
        ssh -i /home/stack/.ssh/id_rsa stack@registry.bluebox.net /opt/mirror/cloudfoundry.sh
        ssh -i /home/stack/.ssh/id_rsa stack@registry.bluebox.net cf ic images > $repo_image_list_file
    fi    
    exit 0
fi

if [ X$credDir == X ]; then
    credDir="operation/environments/$env/heat/group_vars/all"
fi

check_ic_plugin=`cf plugins | grep IBM-Containers | wc -l`
if [ $check_ic_plugin -eq 0 ]; then
    cf install-plugin https://static-ice.ng.bluemix.net/ibm-containers-linux_x64 -f
fi

cf ic images > $repo_image_list_file

login_required=`cat $repo_image_list_file | grep "Please log in to IBM Containers first" | wc -l`
if [ $login_required -eq 0 ]; then
    login_required=`cf ic namespace get | grep -v logmet_dev | wc -l`
fi
if [ $login_required -ne 0 ]; then
    DOCKER_REPO_USER_ID=`cat $credDir | grep DOCKER_REPO_USER_ID: | cut -d ':' -f2 `
    DOCKER_REPO_PASSWORD=`cat $credDir | grep DOCKER_REPO_PASSWORD: | cut -d ':' -f2 `
    DOCKER_REPO_SPACE_NAME=`cat $credDir | grep DOCKER_REPO_SPACE_NAME: | cut -d ':' -f2 `
    DOCKER_REPO_ORG_NAME=`cat $credDir | grep DOCKER_REPO_ORG_NAME: | cut -d ':' -f2 `
    BLUEMIX_AUTH_API=`cat $credDir | grep BLUEMIX_AUTH_API: | cut -d ':' -f2 ` 
    cf login -a $BLUEMIX_AUTH_API -u $DOCKER_REPO_USER_ID -p $DOCKER_REPO_PASSWORD -o $DOCKER_REPO_ORG_NAME -s $DOCKER_REPO_SPACE_NAME
    cf ic login
    cf ic images > $repo_image_list_file
fi
