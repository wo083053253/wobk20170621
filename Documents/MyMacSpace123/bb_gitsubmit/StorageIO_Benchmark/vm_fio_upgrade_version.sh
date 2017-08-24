#!/bin/bash
total_vm_count=60
source ./configuration.properties

timestamp=`grep timestamp $idmap_path | awk '{print $1}'`
ssh_key=fio_ssh_key_$timestamp.pem
chmod 600 $ssh_key

fio_vm_list_file=$temp_path/fio_vm_list_file
sort -t ' ' -k 2n -k 1 $vm_list_file > $fio_vm_list_file

for  ((i = 1 ;i <= $total_vm_count ;i++ ))
do
    vm_ip=`sed -n ${i}p $fio_vm_list_file | awk '{print $5}'`
    vm_name=`sed -n ${i}p $fio_vm_list_file | awk '{print $3}'`
    echo Start check fio version of VM "$vm_name" with "$vm_ip"
    ssh -i $ssh_key -o StrictHostKeyChecking=no $vm_userid@$vm_ip "fio --version"
    ssh -i $ssh_key -o StrictHostKeyChecking=no $vm_userid@$vm_ip "sudo wget http://launchpadlibrarian.net/188146355/fio_2.1.11-2_amd64.deb;sudo apt-get update;sudo dpkg -i fio_2.1.11-2_amd64.deb"
    echo Complete download fio iops log of VM "$vm_name" with "$vm_ip"

    echo Recheck fio version of VM "$vm_name" with "$vm_ip"
    ssh -i $ssh_key -o StrictHostKeyChecking=no $vm_userid@$vm_ip "fio --version"
done
