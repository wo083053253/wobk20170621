#!/bin/bash

cluster_num=1
kafka_topic=topic1


cat /opt/deploy/all_roles >> /var/log/ansible/post_deploy.log
echo $kafka_topic > /opt/deploy/kafka_topic
chown -R ubuntu:ubuntu /var/log/ansible
chown -R ubuntu:ubuntu /opt/deploy/kafka_topic
while read -r line; do
  [ "$line" != "#end" ] && role="$line" || break
  echo "######################### start handle role $role  [`date`] ##########################" >> /var/log/ansible/post_deploy.log
  su - ubuntu -c "/opt/deploy/scripts/config_cluster.sh $role --cluster-num $cluster_num --config-stack false --batch-size 100% --dependencies false"
  echo "################################ after handle $role  [`date`] #################" >> /var/log/ansible/post_deploy.log
done < "/opt/deploy/all_roles"

echo "Start at [`date`]" >> /var/log/ansible/post_deploy.log

cat /opt/deploy/hosts/* > /opt/deploy/hosts/.all
echo "Kafka Topic Creation for logs, check playbook.log for details" >> /var/log/ansible/post_deploy.log
su - ubuntu -c "ansible-playbook -vvv -i /opt/deploy/hosts/.all /opt/deploy/kafka_createtopics.yml --extra-vars "kafkaTopic=$kafka_topic" >> /var/log/ansible/playbook.log" &>> /var/log/ansible/post_deploy.log 
su - ubuntu -c "ansible-playbook -vvv -i /opt/deploy/hosts/.all /opt/deploy/kafka_createtopics.yml --extra-vars "kafkaTopic=swift-restore-$kafka_topic" >> /var/log/ansible/playbook.log" &>> /var/log/ansible/post_deploy.log

# Add the Elasticsearch template into ES
su - ubuntu -c "ansible-playbook -vvv -b -i /opt/deploy/hosts/.all /opt/deploy/es_config.yml >> /var/log/ansible/playbook.log" &>> /var/log/ansible/post_deploy.log

#Register the shard after the deployment
/opt/deploy/scripts/register_shard.sh $kafka_topic
if [ $? == 0 ]; then
   /opt/deploy/scripts/refresh_nginx.sh
else
  echo "fail to register_shard to tenantinfo!" >> /var/log/ansible/post_deploy.log
fi
# mark post-deploy completed
