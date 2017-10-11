#!/bin/bash
#set -x


[ $# -gt 2 ] && echo "Usage: $0 --cluster-num <clusterNum>" && exit 1

# Parse the command line arguments
for i in "$@"; do 
     opt="$1"
     shift
     case "$opt" in
        -n | --cluster-num)
            CLUSTER_NUM="$1"
            shift
            ;;
        '')
            break
            ;;
        *)
            echo "Incorrect argument format or unknown option \"$i\""
            exit 1
            ;;
    esac
done

# setup ssh cmd
SSH_KEY="/home/stack/.ssh/id_rsa"
SSH_USER="stack"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=1200"
SSH_CMD="ssh ${SSH_OPTIONS} -i ${SSH_KEY}"


getESVersionForRole() {
	ROLE=$1

	ES_HOST=$(./get_cluster_host_file.sh ${ROLE} ${CLUSTER_NUM})
	[[ $? -ne 0 ]] && echo "Error getting the cluster host file for cluster ${ROLE} ${CLUSTER_NUM}" && exit 1 
	[[ ! -f "/opt/deploy/hosts/${ES_HOST}" ]] && echo "Error finding file ${ES_HOST}" && exit 1

	# iterate through all the hosts in the given role
	for i in $(cat /opt/deploy/hosts/${ES_HOST}); do
    	if [[ $i != *"_servers"* ]]; then
    		echo "IP: ${i}"
        	${SSH_CMD} ${SSH_USER}@$i sudo docker ps | grep elasticsearch

    	fi
	done

}


getESVersionForRole elasticsearch_master
getESVersionForRole elasticsearch_http
getESVersionForRole elasticsearch_data

