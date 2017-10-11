#!/bin/bash
set -x

rm master.txt slave.txt all_yarn

nodes=`ls /opt/deploy/nodes/*yarn* |sort `

for node in $nodes; do
   echo "Processing node : $node"

   sn=$(basename $node)
   sn=`echo $sn | sed -e 's/_/-/g'`

   source $node
   case "${sn}" in
   *-yarn?master-* ) echo "${address} ln=${sn}.novalocal  sn=${sn}" >>master.txt ;;
   *-yarn?slave-* ) echo "${address} ln=${sn}.novalocal  sn=${sn}" >>slave.txt ;;
   esac

done;

echo '[yarn_master_servers]' >> all_yarn
cat master.txt >> all_yarn
echo '[yarn_slave_servers]' >> all_yarn
cat slave.txt >> all_yarn
rm -f slave.txt master.txt

sed -i -r "s/'//g" all_yarn

mv all_yarn /tmp/all_yarn

