#!/bin/bash

[ -f /etc/apt/sources.list.d/IBM_logmet_stable.list ] ||
    wget -O - https://downloads.opvis.bluemix.net/client/IBM_Logmet_repo_install.sh | bash
