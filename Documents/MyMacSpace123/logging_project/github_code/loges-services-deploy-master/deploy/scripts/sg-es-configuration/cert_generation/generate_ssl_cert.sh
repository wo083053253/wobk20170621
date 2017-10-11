#!/bin/bash
set -e
SERVERID=$1
CLIENTID=$2
CA_PASS=$3
TS_PASS=$3
KS_PASS=$3

./clean.sh
./gen_root_ca.sh $CA_PASS $TS_PASS                         #aq1sw2de# aq1sw2de#
./gen_node_cert.sh $SERVERID $KS_PASS $CA_PASS             #0 aq1sw2de# aq1sw2de#
#./gen_node_cert_openssl.sh "/CN=kirk/OU=client/O=client/L=test/C=de" "kirk" "es-node" aq1sw2de# aq1sw2de#
./gen_client_node_cert.sh $CLIENTID $KS_PASS $CA_PASS      #client aq1sw2de# aq1sw2de#
