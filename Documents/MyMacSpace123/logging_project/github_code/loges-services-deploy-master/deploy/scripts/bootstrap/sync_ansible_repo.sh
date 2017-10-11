#!/bin/bash

BASE=/opt/bootstrap
ANSIBLE=$BASE/ansible
ANSIBLE_REPO="git@github.ibm.com:alchemy-conductors/ansible-server.git"

# Create BASE if it doesn't exist
if [[ ! -d $BASE ]]; then
    sudo mkdir $BASE
    sudo chmod 755 $BASE
    sudo chown stack:stack $BASE
fi

# If ANSBILE exists, fail if it's not clean
if [[ -d $ANSIBLE ]]; then
    cd $ANSIBLE
    count=$( git status --porcelain 2> /dev/null | wc -l )
    if [[ $count > 0 ]]; then
       echo "*** Local ansible repo is not clean. Can't sync with upstream"
       exit 1
    fi
fi

# Delete ANSIBLE repo
cd $BASE
sudo rm -rf "$ANSIBLE"

# Clone ansible repo
echo -- Clone ansible repo
git clone $ANSIBLE_REPO $ANSIBLE

if [[ $? != 0 ]]; then
    echo "*** Error cloning ansible repo"
    exit 1
fi
