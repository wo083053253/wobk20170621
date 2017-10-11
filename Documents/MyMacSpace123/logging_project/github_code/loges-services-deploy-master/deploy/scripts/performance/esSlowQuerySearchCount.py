#!/usr/bin/python
#--------------------------------------------------------------------------------------
# Script to ssh to es data nodes and check for slow query log count
# Takes a optional params : -interval the interval with which script checks logs
#--------------------------------------------------------------------------------------
import os
import json
import argparse
import logging
import subprocess
import time
import datetime
import re
import string
import general_stats_adapter as generalStatsAdapter

#This search pattern is grep'd from es logs
SEARCH_MSG="index.search.slowlog.query"
ES_NODE_FILE="/opt/deploy/hosts/elasticsearch_data_hot"
LOG_FILE= 'elasticsearch_*_index_search_slowlog.log'
ERROR_STATUS = -1
flag=True

OPTS = {
  'sshOptions': "-o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=1200",
  'sshUser': "ubuntu",
  'sshKey': "/home/ubuntu/.ssh/id_rsa"
}


""" Modify the ES file names """
def modify_filenames():

    global ES_NODE_FILE,LOG_FILE

    cmd="ls {0}*".format(ES_NODE_FILE)
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
    (stdout, stderr) = process.communicate()

    ES_NODE_FILE =  stdout.strip()
    LOG_FILE = LOG_FILE.replace("*", ES_NODE_FILE.strip()[-1])


"""Checks container is running or not by doing ssh and then grepping for an SEARCH_MSG """
def check_container_logs(node_ip):

    es_data_log_location ="/var/log/elasticsearch/" + node_ip + "-hot/" +  LOG_FILE
    cmd="ssh {0} -i {1} {2}@{3} sudo grep -r {4} {5} | wc -l ".format(OPTS['sshOptions'], OPTS['sshKey'], OPTS['sshUser'], node_ip, SEARCH_MSG, es_data_log_location)
    status = False

    process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)
    (stdout, stderr) = process.communicate()
    output = int(stdout.strip())
    #if Stderror log it
    if stderr:
        logging.error("Got error while grep for msg "+SEARCH_MSG+" in es data node "+node_ip+" elasticsearch_index_search_slowlog.log file "+stderr)
        status = ERROR_STATUS
    #Pattern matched
    elif output > 0:
        logging.info("Pattern "+SEARCH_MSG+" found in "+node_ip+" Checking timestamps")
        status = True

    return status

"""Checks pattern in container logs and calls the check for timedifference """
def get_logs_pattern(node_ip):

    status = False
    logs =[]
    filtered_logs=[]
    message_stats= 0
    message_log=''

    es_data_log_location ="/var/log/elasticsearch/" + node_ip + "-hot/" +  LOG_FILE
    cmd="ssh {0} -i {1} {2}@{3} sudo grep -r {4} {5}".format(OPTS['sshOptions'], OPTS['sshKey'], OPTS['sshUser'], node_ip, SEARCH_MSG, es_data_log_location)
    process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)

    #Take each line and append in buffer to process
    for line in process.stdout:
        line = line.rstrip()
        logs.append(line)

    #Lines found matching pattern
    status,filtered_logs = filter_and_check_by_logstamp(logs,filtered_logs)

    if status == True:
        message_stats+= len(filtered_logs)

        #Create a string of \n seperated logs
        try:
            log = '\n'.join(filtered_logs)
        except AttributeError:
            log= string.join(filtered_logs,'\n')

        #Append them to message_log
        message_log+=log
    else:
        logging.info("No Errors were found in es data logs with ip "+node_ip)

    return message_stats,message_log

"""Utility method to get time stamp from reg-ex Log Pattern: [2016-06-14 17:50:35,180] INFO Deleting xxx from log alchemy-metrics-4 """
def get_timestamp(log_msg):

    timestamp =""
    ts = re.search('\[(.*?)\]',log_msg).group(1)
    timestamp = ts.split(',',1)[:1]
    return str(timestamp)


"""Utility method to Calculate time delta in seconds """
def calculate_time_delta_seconds(old_time,new_time):

    old_timestamp = time.strptime(old_time, '[\'%Y-%m-%d %H:%M:%S\']')
    new_timestamp = time.strptime(new_time, '[\'%Y-%m-%d %H:%M:%S\']')
    old = time.mktime(old_timestamp)
    new = time.mktime(new_timestamp)
    time_delta = new - old
    return int(time_delta)

"""Checks pattern in container logs and returns true if logs found in last 15 mins, Also returns filtered set of logs """
def filter_and_check_by_logstamp(logs,filtered_logs):

    #Check for last 15 min time stamps & ignore if > 15min
    IGNORE_PAST_TS=900
    status = False
    #Counter to check logs appended
    logs_appended = 0
    #Reverse the grep'd lines to get the latest timestamp
    logs.reverse()
    iter = 0

    #Loop through and compare the time diff
    for line in logs:
        iter += 1
        #Get the last logged time stamp(reversed: so first log) and compare it with current time ignore if > IGNORE_PAST_TS
        if iter == 1:
            last_timestamp =  get_timestamp(line)
            time_now = datetime.datetime.now().strftime('[\'%Y-%m-%d %H:%M:%S\']')
            delta = calculate_time_delta_seconds(last_timestamp,time_now)
            #Check if last log found > IGNORE_PAST_TS
            if delta > IGNORE_PAST_TS:
                return status,filtered_logs

            #Set the status to Log found = True and append to logs
            else:
                status = True
                logs_appended+=1
                filtered_logs.append(line)

        #Time stamps found < IGNORE PAST TS
        else:
            timestamp = get_timestamp(line)
            tdiff = calculate_time_delta_seconds(timestamp,time_now)
            #Check if timestamp for subsequent logs is < IGNORE_PAST_TS
            if tdiff < IGNORE_PAST_TS:
                logs_appended+=1
                filtered_logs.append(line)
            #Break if timestamp is not < IGNORE_PAST_TS
            else:
                break

    return status,filtered_logs


"""main method for initialization"""
def main(args):
    # Parse the arguments
    parser = argparse.ArgumentParser(description='Checks es data nodes for Slow query logs count')

    # define optional parameters
    parser.add_argument('-debug',  action='store_true',  help='Logging level - Enable debug level')
    parser.add_argument('-interval',type=int, help='Script run interval - Set script run interval,(default 15 mins)',default = 900)

    args = parser.parse_args(args)

    # Setup logging, INFO, WARNING, DEBUG
    if args.debug:
        logging.basicConfig(filename='/var/log/es_slow_search_log_rate.log',level=logging.DEBUG)
    else:
        logging.basicConfig(filename='/var/log/es_slow_search_log_rate.log',level=logging.INFO)
    if args.interval:
       SCRIPT_RUN_INTERVAL=args.interval

    #Run the script every script interval seconds
    while True:
        time.sleep(SCRIPT_RUN_INTERVAL)
        try:
            global flag
            flag=True
            check_es_data_nodes()
        except Exception, e:
            logging.error("Caught exception: %s" % e)
            print( "Caught exception: %s" % e)


"""Functions which gets elasticsearch data nodes for slow query alert and runs tests on each one of them """
def check_es_data_nodes():

    message_count=0
    message_log=''
    modify_filenames()

    #Read and skip first line [elasticsearch_data_servers]
    with open(ES_NODE_FILE, 'r') as es_data_hosts_file:
        es_data_hosts = es_data_hosts_file.readlines()[1:]

    #For each node , connect and check status of container and then search log pattern
    for node in es_data_hosts:
        stats=0
        logs=''
        node_ip = node.strip()
        status = check_container_logs(node_ip)
        if status is True:
            stats,logs = get_logs_pattern(node_ip)
            if stats and logs:
                message_count+=stats
                message_log+=logs
                message_log+='\n'

    if message_count == '':
        message_count = 0

    generalStatsAdapter.publishMetrics("es_slow_search_log_rate", message_count, logging)
    #print "count:",message_count


# In case if we run this directly
if __name__ == '__main__':
    import sys
    main(sys.argv[1:])
