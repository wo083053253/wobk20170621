#!/bin/bash
################  Initialization configuration ######################
source ./configuration.properties

kvm_hostname="$1"
vm_seq="$2"
vm_name="$3"
network_name="$4"
network_id="$5"
key="$6"
ssh_key="$7"
secgroup_name="${8}"

# result fields
fixed_ip="N/A"
extra_info="no_info"
#########################  utility functions #############################
log_result()
{
    echo "$kvm_hostname $vm_seq $vm_name $network_name $fixed_ip $extra_info" >> $vm_list_file
}
#########################  Main workflow #############################
#Submit new vm request#
echo "[$(date +%Y%m%d-%H:%M:%S)] Submit create VM $vm_name request from image $image with flavor $flavor"
req_time=$(date +%Y%m%d-%H:%M:%S)
nova boot $vm_name --image "${image}" --flavor $flavor --nic net-id=$network_id --security-groups $secgroup_name --key-name $key --availability-zone "$availability_zone":"$kvm_hostname" >/dev/null
if [ $? != 0 ]; then
    extra_info="create_vm_req_fail_directly"
    echo "[$(date +%Y%m%d-%H:%M:%S)] Create VM $vm_name request failed directly [fail]"
    log_result
    exit 1
fi
echo "[$(date +%Y%m%d-%H:%M:%S)] Create VM $vm_name request submitted"

#Wait for new vm to be active
echo "[$(date +%Y%m%d-%H:%M:%S)] Wait for VM $vm_name to get Active"
start_time=$(date +%s)
while :
do
        vm_status=$(nova show $vm_name | awk '/status/&&/ACTIVE/ {print $(NF-1)}')
        if [ ! -z "$vm_status" ]; then
                break
        fi
        # If vm is not active before timeout, will not wait any more
        current_time=$(date +%s)
        if [ $(($current_time - $start_time)) -gt $vm_waitfor_active_timeout ]; then
            extra_info="vm_not_active_before_timeout"
            echo "[$(date +%Y%m%d-%H:%M:%S)] VM $vm_name failed to get Active before timeout [fail]"
            log_result
            exit 1
        fi
        sleep "$polling_interval"
done
echo "[$(date +%Y%m%d-%H:%M:%S)] VM $vm_name get Active successfully"

sleep 2
vm_info=$(nova show $vm_name)
#Retrieve fixed IP address of the new vm
echo "[$(date +%Y%m%d-%H:%M:%S)] Retrieve fixed IP address of VM $vm_name"
fixed_ip=$(echo "$vm_info" | awk '/'"$network_name"'/ {print $(NF-1)}')
if [ -z "$fixed_ip" ]; then
    extra_info="vm_active_but_no_fixed_ip"
    echo  "[$(date +%Y%m%d-%H:%M:%S)] VM $vm_name is active but not assigned with valid fixed IP [fail]"
    log_result
    exit 1
fi
echo "[$(date +%Y%m%d-%H:%M:%S)] Fixed IP address of VM $vm_name is $fixed_ip"


#Wait for new vm to be able to ping (Allocated with IP via DHCP success)
echo  "[$(date +%Y%m%d-%H:%M:%S)] Wait for VM $vm_name to be ping success"
while :
do
        ping -c 2 $fixed_ip >/dev/null
        status=$?
        if [ $status = 0 ]; then
                break
        fi
        # If vm is not able to ping success before timeout, will not wait any more
        current_time=$(date +%s)
        if [ $(($current_time - $start_time)) -gt $vm_waitfor_ping_timeout ]; then
            extra_info="vm_not_pingable_before_timeout"
            echo "[$(date +%Y%m%d-%H:%M:%S)] VM $vm_name failed to ping (allocated with IP via DHCP) before timeout [fail]"
            log_result
            exit 1
        fi
        sleep "$polling_interval"
done
vm_ping_time=$(($current_time - $start_time))
echo "[$(date +%Y%m%d-%H:%M:%S)] VM $vm_name is able to ping successfully"

#Wait for new vm to be able to SSH(sshd service up and key injection success via metadata service)
echo "[$(date +%Y%m%d-%H:%M:%S)] Wait for VM $vm_name to be SSH/RDP success"
while :
do
        ssh -i $ssh_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GSSAPIAuthentication=no -o BatchMode=yes $vm_userid@$fixed_ip "exit" < /dev/null
        status=$?
        if [ $status = 0 ]; then
                break
        fi
        # If vm is not able to SSH success before timeout, will not wait any more
        current_time=$(date +%s)
        if [ $(($current_time - $start_time)) -gt $vm_waitfor_ssh_rdp_timeout ]; then
            extra_info="vm_not_able_SSH_access_before_timeout"
            echo "[$(date +%Y%m%d-%H:%M:%S)] VM $vm_name failed to SSH access(IP $fixed_ip) before timeout [fail]"
            log_result
            exit 1
        fi
        sleep "$polling_interval"
done
echo "[$(date +%Y%m%d-%H:%M:%S)] VM $vm_name is able to SSH access successfully"

#Submit new volume request#
vol_name="vol"_"$vm_name"

#Retrieve volume id of the new volume
echo "[$(date +%Y%m%d-%H:%M:%S)] Retrieve volumeID of volume $vol_name"
vol_id=$(cinder show $vol_name | awk '/ id / {print $(NF-1)}')

#Submit attach-to-vm request for volume
echo "[$(date +%Y%m%d-%H:%M:%S)] Submit attach volume $vol_name to VM $vm_name request"
nova volume-attach $vm_name $vol_id $vol_attach_device >/dev/null 
status=$?
if [ $status != 0 ]; then
    extra_info="attach_volume_request_fail_directly"
	echo "[$(date +%Y%m%d-%H:%M:%S)] Attach volume $vol_name to VM $vm_name request failed directly"
	log_result
	exit 1
fi
echo "[$(date +%Y%m%d-%H:%M:%S)] Attach volume $vol_name to VM $vm_name request submitted"

#Wait for volume to be in-use
echo "[$(date +%Y%m%d-%H:%M:%S)] Wait for volume $vol_name to get In-use"
start_time=$(date +%s)
while :
do
	vol_status=$(cinder show $vol_name | awk '/status/&&/in-use/ {print $(NF-1)}')
	if [ ! -z "$vol_status" ]; then
		break
	fi							
	# If volume is not active before timeout, will not wait any more
	current_time=$(date +%s)
	if [ $((current_time - start_time)) -gt $vol_waitfor_inuse_timeout ]; then
	    extra_info="volume_not_inuse_before_timeout"
		echo "[$(date +%Y%m%d-%H:%M:%S)] Volume $vol_name attached to VM $vm_name failed to get in-use before timeout"
		log_result
		exit 1
	fi
	sleep "$polling_interval"	
done	
echo "[$(date +%Y%m%d-%H:%M:%S)] Volume $vol_name attached to VM $vm_name successfully"

#Check if volume is attached to target VM device successfully as /dev/v**
echo "[$(date +%Y%m%d-%H:%M:%S)] Check if volume $vol_name attached to VM $vm_name as $vol_attach_device"
sleep 3;
attach_result=$(ssh -i $ssh_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GSSAPIAuthentication=no -o BatchMode=yes $vm_userid@$fixed_ip "sudo fdisk -l | grep $vol_attach_device" < /dev/null) 
if [ -z "$attach_result" ]; then
    extra_info="volume_not_attached_as_specified_device"
	echo  "[$(date +%Y%m%d-%H:%M:%S)] Volume $vol_name is not attached to VM $vm_name as $vol_attach_device via checking with fdisk -l"
	log_result
	exit 1
fi 
echo "[$(date +%Y%m%d-%H:%M:%S)] Volume $vol_name is attached to VM $vm_name as $vol_attach_device successfully via checking with fdisk -l [done]"
log_result
