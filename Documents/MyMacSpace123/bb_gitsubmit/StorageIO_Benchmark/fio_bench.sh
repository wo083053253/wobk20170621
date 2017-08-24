#!/bin/bash
set +x
################  Initialization configuration ######################
sed -i 's/\r//g' ./configuration.properties
sed -i 's/\r//g' ./output/vm_list.txt
source ./configuration.properties

fio_vm_list_file=$temp_path/fio_vm_list_file
sort -t ' ' -k 2n -k 1 $vm_list_file > $fio_vm_list_file
fio_benchmark_result_raw=$temp_path/fio_benchmark_result_raw
rm -rf $fio_benchmark_result_raw
fio_benchmark_result_csvfile=$output_path/fio_benchmark_result.csv
rm -rf $fio_benchmark_result_csvfile
fio_benchmark_result_summary_csvfile=$output_path/fio_benchmark_result_summary.csv
rm -rf $fio_benchmark_result_summary_csvfile
fio_benchmark_vm_realtime_iopslog=$temp_path/fio_benchmark_vm_realtime_iopslog
rm -rf $fio_benchmark_vm_realtime_iopslog
mkdir $fio_benchmark_vm_realtime_iopslog

timestamp=`grep timestamp $idmap_path | awk '{print $1}'`
ssh_key=fio_ssh_key_$timestamp.pem
chmod 600 $ssh_key

#########################  Main workflow #############################
echo "**************************************************************************"
echo "[$(date +%Y%m%d-%H:%M:%S)] Perform storageIO throughput benchmark via FIO "
echo "**************************************************************************"

clean_cache_vm()
{
        if [ $vm_cache_clean_flag == 1 ]; then
            for  ((i = 1 ;i <= $1 ;i ++ ))
            do
                 {
                        vm_ip=`sed -n ${i}p $fio_vm_list_file | awk '{print $5}'`
                        vm_name=`sed -n ${i}p $fio_vm_list_file | awk '{print $3}'`
                        ssh -i $ssh_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $vm_userid@$vm_ip "sudo sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches'"
                        echo Complete cache clean of VM "$vm_name" with "$vm_ip"
                 } &
             done
             wait
        fi
}

clean_cache_kvm()
{
        if [ $kvm_cache_clean_flag == 1 ]; then
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null blueboxadmin@$chef01 "for target_kvm_host in $kvm_host_list;do ssh -F /home/blueboxadmin/deployment/30node-perf/integratedtest-envs/openstack-envs/30node-perf/ssh_config -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null blueboxadmin@\$target_kvm_host \"sudo sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches';echo Complete cache clean of \$target_kvm_host\" & done;wait;"
            #ssh -o StrictHostKeyChecking=no blueboxadmin@$chef01 "for target_kvm_host in $kvm_host_list;do ssh -F /home/blueboxadmin/deployment/tesla/integratedtest-envs/openstack-envs/tesla/ssh_config -o StrictHostKeyChecking=no blueboxadmin@\$target_kvm_host \"sudo sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches';echo Complete cache clean of \$target_kvm_host\" & done;wait;"
            #ssh -o StrictHostKeyChecking=no blueboxadmin@$chef01 "for target_kvm_host in $kvm_host_list;do ssh -F /home/blueboxadmin/deployment/cisdev/integratedtest-envs/openstack-envs/cisdev-ubuntu/ssh_config -o StrictHostKeyChecking=no blueboxadmin@\$target_kvm_host \"sudo sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches';echo Complete cache clean of \$target_kvm_host\" & done;wait;"


            #for target_kvm_host in $kvm_host_list
            #do
            #    #ssh -o StrictHostKeyChecking=no root@$chef01 ssh -o StrictHostKeyChecking=no root@$target_kvm_host "sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches'"
            #    ssh -o StrictHostKeyChecking=no blueboxadmin@$chef01 ssh -F /home/blueboxadmin/CN_team/integratedtest-envs/conv-perf/ssh_config -o StrictHostKeyChecking=no root@$target_kvm_host "sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches'"
            #    echo Complete cache clean of KVM "$target_kvm_host"
            #done
        fi
}

clean_cache_ceph()
{
        if [ $ceph_cache_clean_flag == 1 ]; then
            #ssh -o StrictHostKeyChecking=no  -o UserKnownHostsFile=/dev/null blueboxadmin@$chef01 "for target_ceph_host in $ceph_host_list;do ssh -F /home/blueboxadmin/deployment/30node-perf/integratedtest-envs/openstack-envs/30node-perf/ssh_config -o StrictHostKeyChecking=no root@\$target_ceph_host \"sudo sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches';echo Complete cache clean of \$target_ceph_host\" & done;wait;"
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null blueboxadmin@$chef01 "for target_ceph_host in $ceph_host_list;do ssh -F /home/blueboxadmin/deployment/30node-perf/integratedtest-envs/openstack-envs/30node-perf/ssh_config -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null blueboxadmin@\$target_ceph_host \"sudo sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches';echo Complete cache clean of \$target_ceph_host\" & done;wait;"
            #ssh -o StrictHostKeyChecking=no blueboxadmin@$chef01 "for target_ceph_host in $ceph_host_list;do ssh -F /home/blueboxadmin/deployment/tesla/integratedtest-envs/openstack-envs/tesla/ssh_config -o StrictHostKeyChecking=no blueboxadmin@\$target_ceph_host \"sudo sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches';echo Complete cache clean of \$target_ceph_host\" & done;wait;"
            #ssh -o StrictHostKeyChecking=no blueboxadmin@$chef01 "for target_ceph_host in $ceph_host_list;do ssh -F /home/blueboxadmin/deployment/cisdev/integratedtest-envs/openstack-envs/cisdev-ubuntu/ssh_config -o StrictHostKeyChecking=no blueboxadmin@\$target_ceph_host \"sudo sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches';echo Complete cache clean of \$target_ceph_host\" & done;wait;"
 

            #for target_ceph_host in $ceph_host_list
            #do
            #    #ssh -o StrictHostKeyChecking=no root@$chef01 ssh -o StrictHostKeyChecking=no root@$target_ceph_host "sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches'"
            #    ssh -o StrictHostKeyChecking=no blueboxadmin@$chef01 ssh -F /home/blueboxadmin/CN_team/integratedtest-envs/conv-perf/ssh_config  -o StrictHostKeyChecking=no root@$target_ceph_host "sh -c 'echo 1 >/proc/sys/vm/drop_caches;echo 2 >/proc/sys/vm/drop_caches;echo 3 >/proc/sys/vm/drop_caches'"
            #    echo Complete cache clean of Ceph node "$target_ceph_host"
            #done
        fi
}

clean_realtime_iopslog_vm()
{
        if [ $vm_realtime_iopslog_clean_flag == 1 ]; then
            for  ((i = 1 ;i <= $1 ;i ++ ))
            do
                 {
                        vm_ip=`sed -n ${i}p $fio_vm_list_file | awk '{print $5}'`
                        vm_name=`sed -n ${i}p $fio_vm_list_file | awk '{print $3}'`
                        ssh -i $ssh_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $vm_userid@$vm_ip "sudo rm -f /home/$vm_userid/*_iops.log"
                        echo Complete fio realtime iops log clean of VM "$vm_name" with "$vm_ip"
                 } &
             done
             wait
        fi
}

collect_realtime_iopslog_vm()
{
        roundId=$1
        concurrency=$2
        rw_pattern=$3
        bs=$4        
        if [ $vm_realtime_iopslog_clean_flag == 1 ]; then
            iopslog_path=$fio_benchmark_vm_realtime_iopslog/r${roundId}_c${concurrency}_${rw_pattern}_${bs}
            mkdir $iopslog_path
            for  ((i = 1 ;i <= $concurrency ;i ++ ))
            do
                 {
                        vm_ip=`sed -n ${i}p $fio_vm_list_file | awk '{print $5}'`
                        vm_name=`sed -n ${i}p $fio_vm_list_file | awk '{print $3}'`
                        echo Start download fio iops log of VM "$vm_name" with "$vm_ip"
                        ssh -i $ssh_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $vm_userid@$vm_ip "sudo chmod 777 /home/$vm_userid/*_iops.log"
                        scp -i $ssh_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $vm_userid@$vm_ip:/home/$vm_userid/*_iops.log $iopslog_path
                        echo Complete download fio iops log of VM "$vm_name" with "$vm_ip"
                 } &
             done
             wait
             echo "Use fio2gnuplot to generate iops chart based on collected iops log"
             currentPath=`pwd`
             cd $iopslog_path
             fio2gnuplot -i -g
             cd $currentPath
             #remove unnecessary charts
             ls $iopslog_path | grep -v .log | grep -v compare-result-2D | xargs echo #rm -rf
        fi
}

fio_benchmark()
{
        bm_round_id=$1
        bm_concurrency=$2
        bm_rw_pattern=$3
        bm_bs=$4
 
        #fio base command
        bm_fio_cmd="sudo fio -filename=$fio_filename -direct=$fio_direct -ioengine=$fio_ioengine -rw=$bm_rw_pattern -bs=$bm_bs -name=mytest -iodepth=$fio_iodepth -runtime=$fio_runtime -time_based"
        
        if [ ! -z "$fio_rwmixread" ]; then
            bm_fio_cmd="$bm_fio_cmd -rwmixread=$fio_rwmixread"
        fi

        if [ ! -z "$fio_size" ]; then
            bm_fio_cmd="$bm_fio_cmd -size=$fio_size"
        fi
        echo "***************************************************************************************************************************"
        echo "[$(date +%Y%m%d-%H:%M:%S)] Start FIO benchmark with round($bm_round_id) concurrency($fio_concurrency) $bm_rw_pattern $bm_bs"
        echo "***************************************************************************************************************************"
        echo "************************  Clean memory cache of VM/KVM/Ceph node if specified  ************************"
        clean_cache_vm $bm_concurrency
        clean_cache_kvm
        clean_cache_ceph
        echo "************************  Clean fio realtime iops log of VM node if specified  ************************"
        clean_realtime_iopslog_vm $bm_concurrency
        echo "*******************************************************************************************************"
        if [ $vm_realtime_iopslog_clean_flag == 1 ]; then
             echo FIO benchmark command: $bm_fio_cmd -write_iops_log=vmname_vmip
         else
            echo FIO benchmark command: $bm_fio_cmd
        fi

        fifofile="$$.fifo"
        mkfifo $fifofile
        exec 8<>$fifofile
        for ((i = 0; i < $bm_concurrency; i++))
        do
                echo
        done >&8

        for  ((i = 1 ;i <= $bm_concurrency ;i ++ ))
        do
                read -u 8
                {
                vm_ip=`sed -n ${i}p $fio_vm_list_file | awk '{print $5}'`
                vm_name=`sed -n ${i}p $fio_vm_list_file | awk '{print $3}'`
                bm_raw_log_file=$temp_path/fio_"$bm_round_id"_"$bm_concurrency"_"$bm_rw_pattern"_"$bm_bs"_"$vm_name"_"$vm_ip".log

                 if [ $vm_realtime_iopslog_clean_flag == 1 ]; then
                       bm_fio_cmd="$bm_fio_cmd -write_iops_log=${vm_name}_${vm_ip}"
                fi

                ssh -i $ssh_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q $vm_userid@$vm_ip "$bm_fio_cmd" > $bm_raw_log_file

                echo "$bm_round_id", "$bm_concurrency", "$bm_rw_pattern", "$bm_bs", "$vm_name", "$vm_ip", `awk -F ', ' '/iops/ {OFS=", ";print $(NF-1), $(NF-2)}' $bm_raw_log_file` | tee -a $fio_benchmark_result_raw
                echo >&8
                } &
        done
        wait
        exec 8<&-
        rm -f $fifofile
        echo "************************  Collect fio realtime iops log of VM node if specified  ************************"
        collect_realtime_iopslog_vm $bm_round_id $bm_concurrency $bm_rw_pattern  $bm_bs
        echo "*******************************************************************************************************"
}

result_summary(){
        #echo "round,concurrency,r/w pattern,blocksize,total_iops,total_bw" > $fio_benchmark_result_summary_csvfile;
        #remove the total_bw colume before fixing the mb/s,kb/s,b/s issue  
     
        if [ ! -z "$fio_rwmixread" ]; then
            echo "round,concurrency,r/w pattern,blocksize,total_read_iops,total_write_iops,total_iops" > $fio_benchmark_result_summary_csvfile;                        
        else
            echo "round,concurrency,r/w pattern,blocksize,total_iops" > $fio_benchmark_result_summary_csvfile;
        fi

        for rd in $(seq 1 $fio_round_num)
        do
            for concurrency in $fio_concurrency_list
            do
                for rw_mode in $fio_rw_pattern_list
                do
                    for bs in $fio_bs_list
                    do
                        echo -ne "$rd," >> $fio_benchmark_result_summary_csvfile;
                        echo -ne "$concurrency," >> $fio_benchmark_result_summary_csvfile;
                        echo -ne "$rw_mode," >> $fio_benchmark_result_summary_csvfile;
                        echo -ne "$bs," >> $fio_benchmark_result_summary_csvfile;

                        #sed 's/[][ ]*//g' $fio_benchmark_result_csvfile | awk -F, '$1=='"$rd"'&&$2=='"$concurrency"'&&$3=="'"$rw_mode"'"&&$4=="'"$bs"'" {if($9=="B/s")print $7, $8/1000;else print $7, $8}' | awk 'BEGIN{iops=0;tp=0}{iops+=$1;tp+=$2}END{printf("%.f,%.f\n"), iops, tp}' >> $fio_benchmark_result_summary_csvfile;
                        #no longer calculate the total bandwidth before fixing the mb/s,kb/s,b/s issue

                        if [ ! -z "$fio_rwmixread" ]; then
                            sed 's/[][ ]*//g' $fio_benchmark_result_csvfile | awk -F, '$1=='"$rd"'&&$2=='"$concurrency"'&&$3=="'"$rw_mode"'"&&$4=="'"$bs"'" {print $7, $9}' | awk 'BEGIN{read_iops=0;write_iops=0;total_iops=0;}{read_iops+=$1;write_iops+=$2;total_iops=read_iops+write_iops}END{printf("%.f,%.f,%.f\n"), read_iops, write_iops, total_iops}' >> $fio_benchmark_result_summary_csvfile;
                        else
                            sed 's/[][ ]*//g' $fio_benchmark_result_csvfile | awk -F, '$1=='"$rd"'&&$2=='"$concurrency"'&&$3=="'"$rw_mode"'"&&$4=="'"$bs"'" {print $7}' | awk 'BEGIN{iops=0}{iops+=$1;}END{printf("%.f\n"), iops}' >> $fio_benchmark_result_summary_csvfile;
                        fi
                   done
               done
           done
       done
}



for ((fio_round_id = 1; fio_round_id <= $fio_round_num; fio_round_id++))
do
        for fio_concurrency in $fio_concurrency_list
                do
                        for fio_rw_pattern in $fio_rw_pattern_list
                        do
                                for fio_bs in $fio_bs_list
                                do
                                        fio_benchmark $fio_round_id $fio_concurrency $fio_rw_pattern $fio_bs;
                                        echo "Sleep $sleep_interval seconds before triggering next test"
                                        sleep $sleep_interval
                                done
                        done
                done
done
echo "**************************************************************************************"
echo "[$(date +%Y%m%d-%H:%M:%S)] Summary result of storageIO throughput benchmark via FIO "
echo "**************************************************************************************"

cat $fio_benchmark_result_raw
sed -i "s/iops=//g" $fio_benchmark_result_raw
sed -i "s/bw=//g" $fio_benchmark_result_raw
#sed -i "s/KB\/s/,KB\/s/g" $fio_benchmark_result_raw
#sed -i "s/MB\/s/,MB\/s/g" $fio_benchmark_result_raw
#sed -i "s/ B\/s/,B\/s/g" $fio_benchmark_result_raw
sed -i "s/\/s/\/s,/g" $fio_benchmark_result_raw
sed -i "s/ ,/,/g" $fio_benchmark_result_raw

if [ ! -z "$fio_rwmixread" ]; then
    echo "round, concurrency, r/w pattern, blocksize, vm_name, ip_addr, read_iops, read_bw, write_iops, write_bw" > $fio_benchmark_result_csvfile
else
    echo "round, concurrency, r/w pattern, blocksize, vm_name, ip_addr, iops, bw" > $fio_benchmark_result_csvfile
fi
cat $fio_benchmark_result_raw >> $fio_benchmark_result_csvfile

result_summary

rm -f $output_path/fio_raw_log_*.tar.gz
tar czf $output_path/fio_raw_log_$(date +%Y%m%d-%H%M%S).tar.gz $temp_path/fio_*.log
rm -f $temp_path/fio_*.log

exit 0
