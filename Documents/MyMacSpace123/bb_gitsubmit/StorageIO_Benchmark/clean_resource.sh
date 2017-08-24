#!/bin/bash
source configuration.properties

timestamp=`grep timestamp $idmap_path | awk '{print $1}'`

echo "Delete VM resource"
for i in `nova list | grep $timestamp | awk '{print $2}'`
do
    nova delete $i;
        sleep 2;
done
sleep 30;

echo "Delete keypair resource"
for key_name in `nova keypair-list | grep $timestamp | awk '{print $2}'`
do
    echo "-- Delete keypair $key_name"
    nova keypair-delete $key_name;
done
ssh_key=fio_ssh_key_$timestamp.pem
rm -f $ssh_key

echo "Delete security group resource"
secgroup_list=$(neutron security-group-list)
for secgroup_id in `echo "$secgroup_list" | grep $timestamp | awk '{print $2}'`
do
    secgroup_name=`echo "$secgroup_list" | grep $secgroup_id | awk '{print $4}'`
    echo "-- Delete security group $secgroup_name ($secgroup_id)"
    neutron security-group-delete $secgroup_id;
done

#echo "Delete volume resource"
#for vol_name in `cinder list | grep $timestamp | awk '{print $2}'`
#do
#    echo "-- Delete volume $vol_name"
#    cinder delete $vol_name;
#     sleep 5;
#done
