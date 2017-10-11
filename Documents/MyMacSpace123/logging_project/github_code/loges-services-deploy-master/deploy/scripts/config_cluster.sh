#!/bin/bash
set -x

[ "$#" -lt 1 ] && (echo "Usage: $0 <role_name> --dependencies | --cluster-num | --config-stack | --batch-size | --es-change-type | --cf-auth-refresh-interval | --ucd_deploy" && exit 1)

role=$1 # Accept the role as the first positional argument
declare -A multicluster=([elasticsearch_master]=1 [elasticsearch_http]=1 [elasticsearch_data_hot]=1 [elasticsearch_data_warm]=1 [elasticsearch_lb]=1 [logstash]=1 [logstash_fastforwarder]=1 [logstash_objstore]=1)

{
    flock 100
    shift
    for i in "$@"; do # Parse the remaining command line arguments in the standard fashion
         opt="$1"
         shift
         case "$opt" in
            -d | --dependencies)
                dependencies="$1"
                shift
                ;;
            -n | --cluster-num)
                cluster_num="$1"
                shift
                ;;
            -c | --config-stack)
                config_stack="$1"
                shift
                ;;
            -b | --batch-size)
                batch_size="$1"
                shift
                ;;
            -e | --es-change-type)
                es_change_type="$1"
                shift
                ;;
            -i | --cf-auth-refresh-interval)
                cf_auth_refresh_interval="$1"
                shift
                ;;
            -u | --ucd_deploy)
                ucd_deploy="$1"
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

    # Assign default values to the optional command line args if they are empty
    [ -z "$dependencies" ] && dependencies="false"
    [ -z "$config_stack" ] && config_stack="true"
    [ -z "$batch_size" ] && batch_size=1
    [ -z "$es_change_type" ] && es_change_type="es_update"
    [ -z "$cf_auth_refresh_interval" ] && cf_auth_refresh_interval=360
    [ -z "$ucd_deploy" ] && ucd_deploy="false"

    # Enter the /opt/deploy directory
    cd `dirname $0`/../

    # Check if multi_cluster is enabled
    MULTI_CLUSTER_ENABLED=$(grep "MULTI_CLUSTER_ES_ENABLED" /opt/deploy/group_vars/all | awk -F ": " '{print $2}')

    # Function to check if the role being configured is part of the Elasticsearch cluster and set the host_file_name accordingly.
    # Fail if cluster_num is not defined
    function get_host_file_name() {
        local role=$1
        local host_file_name=$role
        if [[ "$MULTI_CLUSTER_ENABLED" -eq 1 ]]; then
            if [[ ${multicluster[$role]} ]]; then
                if [ -z "$cluster_num" ]; then
                    echo "WARNING: the \"--cluster-num\" argument must be defined when \"$role\" is being configured."
                    exit 1
                fi
                host_file_name=${role}_${cluster_num}
            fi
        else
            if [ -e "hosts/elasticsearch_http_1" ]; then
               if [[ ${multicluster[$role]} ]]; then
                  host_file_name=${role}_1
               fi
            fi
        fi

        echo "$host_file_name"
    }

    # Recursive function to intelligently select the correct host files from the role dependencies
    function get_role_dependencies() {
        local role_deps=$1
        for item in $role_deps; do
            local nested_role_deps=$(grep 'include' ${item}.yml | awk -F "[.: ]" '{print $4}')
            local host_file_name=$(get_host_file_name $item)
            cat hosts/${host_file_name} >> temp_inventory
            get_role_dependencies "$nested_role_deps"
        done
    }

    # Set the global host file name for the role
    host_file_name=$(get_host_file_name $role)
    [ -f hosts/"${host_file_name}" ] || exit 1

    # If the user wants to configure dependencies, we cannot use .all file with multicluster
    # or it will configure BOTH elasticsearch clusters. Instead, we extract the dependencies
    # defined in /opt/deploy/${role}.yml and intelligently select the correct host files
    if [ "$dependencies" == true ]; then
        cat hosts/${host_file_name} > temp_inventory
        role_deps=$(grep 'include' ${role}.yml | awk -F "[.: ]" '{print $4}')
        get_role_dependencies "${role_deps}"
    elif [ "${role}" == "elasticsearch_lb" ]; then
        lb_hosts=`tail -n 2 hosts/${host_file_name}`
        lb_hosts_list=(`echo ${lb_hosts}`)
        echo "[elasticsearch_lb_master]" > temp_inventory
        echo ${lb_hosts_list[0]} >> temp_inventory
        echo "[elasticsearch_lb_backup]" >> temp_inventory
        echo ${lb_hosts_list[1]} >> temp_inventory
    else
        cp hosts/${host_file_name} temp_inventory
    fi

    # Define the extra_vars, run the Ansible playbooks
    evars="config_stack=${config_stack} rolling_update_batch_size=${batch_size} es_change_type=${es_change_type} "
    if [ "$ucd_deploy" = "true" || "$ucd_deploy" == true ]; then
        evars+="ucd_deploy=$ucd_deploy "
    fi
    
    # just load variables from extra_vars for elasticsearch_lb
    if [ -f scripts/extra_vars.sh ]; then
        if [ "$role" = "elasticsearch_lb" ]; then
            evars=$(scripts/extra_vars.sh $role $cluster_num)
        else
            evars+=$(scripts/extra_vars.sh $role $cluster_num)
        fi
    fi
    date
    echo "=========########### start to do play $role############################ ========================"
    `cat /opt/deploy/temp_inventory`

    ansible-playbook -b -vvv -i temp_inventory ${role}.yml --extra-vars="$evars"

    flock -u 100
} 100<>/tmp/register.lock
