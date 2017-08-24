#!/bin/bash
################  Initialization configuration ######################
sed -i 's/\r//g' ./configuration.properties
source ./configuration.properties

rm -r $temp_path
rm -r $output_path
mkdir $temp_path
mkdir $output_path

################ Utility function ######################
append_IDmap()
{
    id=$1
    value=$2
    echo "$id $value" >> $idmap_path
}
get_IDmap()
{
    value=$1
    grep $value $idmap_path | awk '{print $1}'
}

timestamp=$(date +%Y%m%d%H%M%S)
append_IDmap $timestamp timestamp
#########################  Initialization workflow #############################

##### keypair setup
key_name=fio_key_$timestamp
private_key_file=fio_ssh_key_$timestamp.pem
echo "[$(date +%Y%m%d-%H:%M:%S)] Create keypair $key_name and download private key file $private_key_file"
nova keypair-add $key_name > $private_key_file
if [ $? != 0 ]; then
        echo "[$(date +%Y%m%d-%H:%M:%S)] Failed to create keypair $key_name.";exit 1
fi
chmod 600 $private_key_file

#copy private key file to output folder for archive
cp $private_key_file $output_path/
chmod 666 $output_path/$private_key_file 

##### security group setup
secgroup_name=secgroup_$timestamp
echo "[$(date +%Y%m%d-%H:%M:%S)] Create security group $secgroup_name and allow all ports ingress"
neutron security-group-create --description permissive $secgroup_name
if [ $? != 0 ]; then
        echo "[$(date +%Y%m%d-%H:%M:%S)] Failed to create security group $secgroup_name.";exit 1
fi
neutron security-group-rule-create --direction ingress $secgroup_name
if [ $? != 0 ]; then
        echo "[$(date +%Y%m%d-%H:%M:%S)] Failed to add secgroup rule to allow all port ingress.";exit 1
fi

##### Retrieve network ID
echo "[$(date +%Y%m%d-%H:%M:%S)] Retrieve network ID of network $network_name"
network_id=$(neutron net-show $network_name | grep " id " | awk '{print $4}')
if [ -z "$network_id" ]; then
        echo "[$(date +%Y%m%d-%H:%M:%S)] Failed to Retrieve network ID of network $network_name.";exit 1
fi

##### VM setup
rm -rf $vm_list_file
fifofile="$$.fifo"
mkfifo $fifofile
exec 6<>$fifofile
for ((i = 0; i < $concurrency; i++))
do
    echo
done >&6

for  ((i = 0 ;i < $vm_num_per_kvm_host ;i ++ ))
do
    for kvm_host in $kvm_list
	do
	read -u 6
	{
	./vm_provision_thread.sh "$kvm_host" $i fio_vm_"$kvm_host"_"$i"_"$timestamp" "$network_name" $network_id $key_name $private_key_file $secgroup_name 
       #./vm_provision_thread.sh "$kvm_host".blueboxgrid.com $i fio_vm_"$kvm_host"_"$i"_"$timestamp" "$network_name" $network_id $key_name $private_key_file $secgroup_name 
    echo >&6
    } & 
    done
done

wait
exec 6<&-
rm -f $fifofile
