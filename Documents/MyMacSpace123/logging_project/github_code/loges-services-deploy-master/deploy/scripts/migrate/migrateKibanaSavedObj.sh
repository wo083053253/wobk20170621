#!/bin/bash
#------------------------------------------------------------------
# This script written for exporting saved objects
# search/visualization/dashboard in .kibana index
# and importing them to local stack
#-----------------------------------------------------------------

script=$(basename $0)

function usage() {
         echo "usage: $script remoteStack_ManagerIP  pathToStackKey localElasticsearch_lb_IP "

         echo "Get all the saved objects(search, visualization, dashboard) in .kibana index for ES in the given $migrateKibanaSavedObj.sh and import them to ${migrateKibanaSavedObj.sh}"
}

function getSavedObj() {
         local index=".kibana"

         multiServerIP=$( ssh -i $stack_key_path stack@$manager_ip "(tail -n 1 /opt/deploy/hosts/multiserver_lb)")
         echo "multiserver_lb_ip is ${multiServerIP}"
         es="http://$multiServerIP:9200"
         for doctype in "search" "visualization" "dashboard"
         do
             countN="$(ssh -i $stack_key_path stack@$manager_ip "curl -s $es/$index/$doctype/_count?pretty | jq -r '.count'" )"
             echo "Doc count for ${doctype}: ${countN}"
             URL="'$es/$index/$doctype/_search?size=$countN&pretty'"
             echo $URL
             if [[ $countN != 0 ]]; then
                 ssh -i $stack_key_path stack@$manager_ip "curl -s ${URL}" > /tmp/${doctype}.json
             fi
         done
}

function convertToBulkFormat() {
         ./convertPython.py -i /tmp/search.json -o searchBulk.json
         ./convertPython.py -i /tmp/visualization.json -o visualizationBulk.json
         ./convertPython.py -i /tmp/dashboard.json -o dashboardBulk.json
}

function getObjCount(){
         savedObjCount="$(curl -s http://$1:9200/.kibana/$2/_count?pretty | jq -r '.count' )"
         echo "./kibana/${2} count is ${savedObjCount}"
}

function insert_to_kibana_index(){
         echo "Before insert search objects:"
         getObjCount $1 search
         curl -XPOST "http://$1:9200/.kibana/_bulk?pretty" --data-binary "@searchBulk.json"
         echo "After insert search objects:"
         getObjCount $1 search
         echo "Before insert visualization objects:"
         getObjCount $1 visualization
         curl -XPOST "http://$1:9200/.kibana/_bulk?pretty" --data-binary "@visualizationBulk.json"
         echo "After insert visualization objects:"
         getObjCount $1 visualization
         echo "Before insert dashboard objects:"
         getObjCount $1 dashboard
         curl -XPOST "http://$1:9200/.kibana/_bulk?pretty" --data-binary "@dashboardBulk.json"
         echo "After insert dashboard objects:"
         getObjCount $1 dashboard
}

function cleanup(){
         rm -f /tmp/search.json
         rm -f /tmp/visualization.json
         rm -f /tmp/dashboard.json
         rm -f searchBulk.json
         rm -f visualizationBulk.json
         rm -f dashboardBulk.json
}


#---------------------------------------------------------------
# main script
#---------------------------------------------------------------

manager_ip=$1
stack_key_path=$2
elastic_lb_dest=$3
echo "Manager IP is ${manager_ip}"
echo "Stack key is ${stack_key_path}"
echo "Elasticsearch destination LB is ${elastic_lb_dest}"
echo "Getting saved objects from ES in  ${manager_ip} stack"
getSavedObj

echo "Converting saved objects to Bulk format"
convertToBulkFormat

echo "Inserting saved objects to .kibana index"
insert_to_kibana_index $elastic_lb_dest

echo "Cleaning up the temporary files"
cleanup



