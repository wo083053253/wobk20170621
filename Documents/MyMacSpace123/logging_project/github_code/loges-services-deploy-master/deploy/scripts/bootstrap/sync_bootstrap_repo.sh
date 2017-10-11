#!/bin/bash

BASE=/opt/bootstrap
BOOTSTRAP=$BASE/bootstrap
BOOTSTRAP_REPO="git@github.ibm.com:alchemy-logmet/bootstrap-playbooks.git"
CONDUCTOR_BOOTSTRAP_REPO="git@github.ibm.com:alchemy-conductors/bootstrap-playbooks.git"

# Create BASE if it doesn't exist
if [[ ! -d $BASE ]]; then
    sudo mkdir $BASE
    sudo chmod 755 $BASE
    sudo chown stack:stack $BASE
fi

# If BOOTSTRAP exists, fail if it's not clean
if [[ -d $BOOTSTRAP ]]; then
    cd $BOOTSTRAP
    count=$( git status --porcelain 2> /dev/null | wc -l )
    if [[ $count > 0 ]]; then
       echo "*** Local bootstrap repo is not clean. Can't sync with upstream"
       exit 1
    fi
fi

# Delete BOOTSTRAP
cd $BASE
sudo rm -rf "$BOOTSTRAP"

# Clone bootstrap repo
echo -- Clone bootstrap repo
git clone $BOOTSTRAP_REPO $BOOTSTRAP

# Set upstream repo
cd $BOOTSTRAP
git remote add upstream "$CONDUCTOR_BOOTSTRAP_REPO"

# Merge upstream changes
echo
echo -- Merge upstream changes
git pull --no-edit upstream master

if [[ $? != 0 ]]; then
    echo "*** Error getting upstream changes"
    exit 1
fi

# Push upstream changes to origin
echo
echo -- Push upstream changes to origin
git push origin master

if [[ $? != 0 ]]; then
    echo "*** Error pushing upstream changes to origin"
    exit 1
fi
