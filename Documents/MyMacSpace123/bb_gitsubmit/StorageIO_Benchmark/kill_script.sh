#!/bin/bash
for i in `ps -ef | grep env_setup.sh | grep -v grep | awk '{print $2}'`; do kill -9 $i; done;
for i in `ps -ef | grep vm_provision_thread.sh | grep -v grep | awk '{print $2}'`; do kill -9 $i; done;
for i in `ps -ef | grep fio_bench.sh  | grep -v grep | awk '{print $2}'`; do kill -9 $i; done;
#kill all the ssh connection to VMs that runing remote fio command
source ./configuration.properties
timestamp=`grep timestamp $idmap_path | awk '{print $1}'`
ssh_key=fio_ssh_key_$timestamp.pem
for i in `ps -ef | grep $ssh_key  | grep -v grep | awk '{print $2}'`; do kill -9 $i; done;
