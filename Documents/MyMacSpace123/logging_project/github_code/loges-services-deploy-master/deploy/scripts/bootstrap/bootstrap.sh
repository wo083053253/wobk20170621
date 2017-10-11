#!/bin/bash

/opt/deploy/scripts/bootstrap/sync_ansible_repo.sh

/opt/deploy/scripts/bootstrap/sync_bootstrap_repo.sh

/opt/bootstrap/bootstrap/scripts/bootstrap_logmet.sh
