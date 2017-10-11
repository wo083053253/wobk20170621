#!/bin/bash
# script to create monitor server definition from eventgen_rest definitions

sed 's/eventgen_rest_servers/monitor_servers/' /opt/deploy/hosts/eventgen_rest > /opt/deploy/hosts/monitor
