#!/bin/bash
#
# This is a simple script to assist with the migration from alogpass to
# tenantinfo during the upgrade process.
#
#

# We're going to re-use the alogpass hosts rather than deploy new ones
cp /opt/deploy/hosts/alogpass /opt/deploy/hosts/tenantinfo
sed -i 's/alogpass/tenantinfo/g' /opt/deploy/hosts/tenantinfo

# Re-use the load balancers
cp /opt/deploy/floatings/alogpass_lb /opt/deploy/floatings/tenantinfo_lb

# Copy the certs
mkdir /opt/deploy/files/tenantinfo
cp /opt/deploy/files/alogpass/* /opt/deploy/files/tenantinfo

# Add a dummy version entries for tenantinfo & redis, if necessary
TENANTINFO_EXISTS=`grep tenantinfo_version /opt/deploy/group_vars/versions`
if [ -z  "${TENANTINFO_EXISTS}" ]; then
   echo "op_services_tenantinfo_version: '0'" >> /opt/deploy/group_vars/versions
fi
REDIS_EXISTS=`grep redis_version /opt/deploy/group_vars/versions`
if [ -z "${REDIS_EXISTS}" ]; then
  echo "op_services_redis_version: '0'" >> /opt/deploy/group_vars/versions
fi

echo "If you are using UCD for this logmet stack, go update the environment for each of the alogpass nodes to add the tenantinfo & redis entries alongside alogpass"


