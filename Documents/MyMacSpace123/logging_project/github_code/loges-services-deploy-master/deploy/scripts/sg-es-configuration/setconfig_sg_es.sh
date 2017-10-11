#!/bin/bash
#---------This script should be executed after running cert_generation-------
#set -e

#es_instance_name=$1
SERVERID=$1
KS_PASS=$2
TS_PASS=$2

HOSTIP=$(ifconfig eth0 |grep "inet addr"| cut -f 2 -d ":"|cut -f 1 -d " ")

nodename=$(hostname)

if [[ $nodename =~ "master" ]]; then
  es_instance_name="master"
elif [[ $nodename =~ "hot" ]]; then
  es_instance_name="hot"
elif [[ $nodename =~ "warm" ]]; then
  es_instance_name="warm"
elif [[ $nodename =~ "http" ]]; then
  es_instance_name="http"
fi

BASE_DIR="/usr/share/elasticsearch"
SGCONFIG_DIR="$BASE_DIR/plugins/search-guard-5/sgconfig"
ES_CONF_DIR="/etc/elasticsearch/$es_instance_name"
ES_CONF_FILE="$ES_CONF_DIR/elasticsearch.yml"
ES_BIN_DIR="$BASE_DIR/bin"
ES_PLUGINS_DIR="$BASE_DIR/plugins"
ES_LIB_PATH="$BASE_DIR/lib"

#DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#CERT_DIR="$DIR/cert_generation"
CERT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

SUDO_CMD=""

echo "## Search Guard Configuration Start ##"

#check related file and directory

if [ -f /usr/share/elasticsearch/bin/elasticsearch ]; then
    ES_CONF_FILE="/etc/elasticsearch/$es_instance_name/elasticsearch.yml"
    ES_BIN_DIR="/usr/share/elasticsearch/bin"
    ES_PLUGINS_DIR="/usr/share/elasticsearch/plugins"
    ES_LIB_PATH="/usr/share/elasticsearch/lib"
    SUDO_CMD="sudo"
fi

if $SUDO_CMD test -f "$ES_CONF_FILE"; then
    :
else
    echo "Unable to determine elasticsearch config directory. Quit."
    exit -1
fi

if [ ! -d $ES_BIN_DIR ]; then
	echo "Unable to determine elasticsearch bin directory. Quit."
	exit -1
fi

if [ ! -d $ES_PLUGINS_DIR ]; then
	echo "Unable to determine elasticsearch plugins directory. Quit."
	exit -1
fi

if [ ! -d $ES_LIB_PATH ]; then
	echo "Unable to determine elasticsearch lib directory. Quit."
	exit -1
fi


ES_CONF_FILE="$ES_CONF_DIR/elasticsearch.yml"


KEYSTORE_FILE=$CERT_DIR/node-$SERVERID-keystore.jks
TRUSTSTORE_FILE=$CERT_DIR/truststore.jks
CLIENTSTORE_FILE=$CERT_DIR/client-keystore.jks

if [ -f $KEYSTORE_FILE ]; then
  $SUDO_CMD cp $KEYSTORE_FILE $ES_CONF_DIR
else
    echo "Unable to determine KEYSTORE FILE. Quit."
    exit -1
fi

if [ -f $TRUSTSTORE_FILE ]; then
  $SUDO_CMD cp $TRUSTSTORE_FILE $ES_CONF_DIR
  $SUDO_CMD cp $TRUSTSTORE_FILE $SGCONFIG_DIR
else
    echo "Unable to determine TRUSTSTORE FILE. Quit."
    exit -1
fi

if [ -f $CLIENTSTORE_FILE ]; then
  $SUDO_CMD cp $CLIENTSTORE_FILE $SGCONFIG_DIR
else
    echo "Unable to determine CLIENTSTORE FILE. Quit."
fi

#Insert sg configuration to elasticsearch config file
echo ""  >>  $ES_CONF_FILE
echo "######## Start Search Guard Configuration ########"  >> $ES_CONF_FILE
echo "searchguard.ssl.transport.enabled: true" >> $ES_CONF_FILE
echo "searchguard.ssl.transport.keystore_filepath: node-$SERVERID-keystore.jks"  >>  $ES_CONF_FILE
echo "searchguard.ssl.transport.keystore_password: $KS_PASS"  >>  $ES_CONF_FILE
echo "searchguard.ssl.transport.truststore_filepath: truststore.jks"  >> $ES_CONF_FILE
echo "searchguard.ssl.transport.truststore_password: $TS_PASS"  >> $ES_CONF_FILE
echo "searchguard.ssl.transport.enforce_hostname_verification: false"  >>  $ES_CONF_FILE
echo "searchguard.ssl.transport.resolve_hostname: false" >> $ES_CONF_FILE
echo -e "\n"  >>  $ES_CONF_FILE
echo "searchguard.ssl.http.enabled: true"  >> $ES_CONF_FILE
echo "searchguard.ssl.http.keystore_filepath: node-$SERVERID-keystore.jks"  >> $ES_CONF_FILE
echo "searchguard.ssl.http.keystore_password: $KS_PASS"  >> $ES_CONF_FILE
echo "searchguard.ssl.http.truststore_filepath: truststore.jks"  >> $ES_CONF_FILE
echo "searchguard.ssl.http.truststore_password: $TS_PASS"  >> $ES_CONF_FILE
echo "searchguard.authcz.admin_dn:"  >> $ES_CONF_FILE
echo "  - CN=kirk,OU=client,O=client,L=test, C=de"  >> $ES_CONF_FILE
echo ""  >> $ES_CONF_FILE
#echo "cluster.name: searchguard_demo"  >> $ES_CONF_FILE
#echo "network.host: 0.0.0.0"  >> $ES_CONF_FILE
echo "######## End Search Guard Configuration ########"  >> $ES_CONF_FILE

iptag=$(echo $HOSTIP|awk -F "." '{print $4}')
sed -i '/node.name/d' $ES_CONF_FILE
echo "node.name: node-${iptag}-${es_instance_name}" >>  $ES_CONF_FILE

##Service restart elasticsearch
sudo service "${es_instance_name}_elasticsearch" restart
worktag="$HOSTIP:9300"
start_time=$(date +%s)
while :
do
  es_status=$(sudo netstat -lntp|grep $worktag)
  if [ ! -z "$es_status" ];then
    echo "elasticsearch service started"
    break
  fi
  current_time=$(date +%s)
  if [ $(($current_time - $start_time)) -gt 300 ]; then
        echo "service restart timeout"
        exit 1
    fi
  echo "waiting service up"
  sleep 5
done
#
#Prepare sg initial command shell
$SUDO_CMD chmod +x "$ES_PLUGINS_DIR/search-guard-5/tools/sgadmin.sh"

ES_PLUGINS_DIR=`cd "$ES_PLUGINS_DIR" ; pwd`
TMPDIR="/tmp/sg-es-configuration/"
echo "### Success"
echo "### Execute this script now on all your nodes and then start all nodes"
echo "### After the whole cluster is up execute: "
echo "#!/bin/bash"  > $TMPDIR/sgadmin_initial.sh
echo $SUDO_CMD "$ES_PLUGINS_DIR/search-guard-5/tools/sgadmin.sh" -cn elasticsearch_2 -h $HOSTIP -cd "$ES_PLUGINS_DIR/search-guard-5/sgconfig" -ks "$ES_CONF_DIR/node-$SERVERID-keystore.jks" -kspass $KS_PASS -ts "$ES_CONF_DIR/truststore.jks" -tspass $TS_PASS -nhnv --diagnose >> $TMPDIR/sgadmin_initial.sh
$SUDO_CMD chmod +x $TMPDIR/sgadmin_initial.sh
