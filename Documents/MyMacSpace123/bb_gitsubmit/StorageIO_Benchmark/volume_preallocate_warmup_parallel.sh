#!/bin/bash
source ./configuration.properties

#total_vm_count=60
total_vm_count=`cat $vm_list_file | wc -l`
parallel_count=3


if [ -n $parallel_user_count ]; then
	parallel_count=$parallel_user_count
fi
echo "parallel_count=$parallel_count"

timestamp=`grep timestamp $idmap_path | awk '{print $1}'`
ssh_key=fio_ssh_key_$timestamp.pem
chmod 600 $ssh_key

fio_vm_list_file=$temp_path/fio_vm_list_file
sort -t ' ' -k 2n -k 1 $vm_list_file > $fio_vm_list_file

for i in $(seq 1 $parallel_count $total_vm_count)
do
	for j in $(seq $i $(($i + $parallel_count - 1)))
	do
    	vm_ip=`sed -n ${j}p $fio_vm_list_file | awk '{print $5}'`
    	vm_name=`sed -n ${j}p $fio_vm_list_file | awk '{print $3}'`
    	echo Start volume pre-allocate warmup of VM "$vm_name" with "$vm_ip"
    	ssh -i $ssh_key -o StrictHostKeyChecking=no  -o UserKnownHostsFile=/dev/null $vm_userid@$vm_ip "sudo fio -filename=$fio_filename -direct=$fio_direct -ioengine=$fio_ioengine -rw=write -bs=512k -name=warmup -iodepth=5 -size=${vol_size}G" &
	done
	wait
       echo Complete volume pre-allocate warmup of VM number $i to $(( $i + $parallel_count - 1))
done
