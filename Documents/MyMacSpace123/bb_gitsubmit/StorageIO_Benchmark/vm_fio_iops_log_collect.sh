#!/bin/bash
total_vm_count=10
source ./configuration.properties

timestamp=`grep timestamp $idmap_path | awk '{print $1}'`
ssh_key=fio_ssh_key_$timestamp.pem
chmod 600 $ssh_key

fio_vm_list_file=$temp_path/fio_vm_list_file
sort -t ' ' -k 2n -k 1 $vm_list_file > $fio_vm_list_file

rm -rf ./fio_iops_log
mkdir ./fio_iops_log
for  ((i = 1 ;i <= $total_vm_count ;i++ ))
do
    vm_ip=`sed -n ${i}p $fio_vm_list_file | awk '{print $5}'`
    vm_name=`sed -n ${i}p $fio_vm_list_file | awk '{print $3}'`
    echo Start download fio iops log of VM "$vm_name" with "$vm_ip"
    ssh -i $ssh_key -o StrictHostKeyChecking=no $vm_userid@$vm_ip "sudo chmod 777 /home/ibmcloud/*.log"
    scp -i $ssh_key -o StrictHostKeyChecking=no $vm_userid@$vm_ip:/home/ibmcloud/*.log ./fio_iops_log/
    ssh -i $ssh_key -o StrictHostKeyChecking=no $vm_userid@$vm_ip "sudo rm -f /home/ibmcloud/*.log"
    echo Complete download fio iops log of VM "$vm_name" with "$vm_ip"
done
chown -R jenkins:jenkins ./fio_iops_log
cd ./fio_iops_log
fio2gnuplot -i -g


