#!/usr/bin/python

import os
import statsd
import logging
os.environ

client = statsd.StatsClient('localhost', 8125)

'''
Method that publishes the metrics to statsd plugin running in collectd
@param metric_name: Name of the metrics to be published
@param metric_value: Value of the metrics to be published
@param logger: logger object
'''
def publishMetrics(metric_name, metric_value, logger):
    try:
        # Format the keys
        value = float(metric_value)

        # Send the gauge data
        logger.debug("Sending gauge %s=%s", metric_name, value)
        client.gauge(metric_name, value)
        logger.debug("Successfully sent gauge, %s", metric_name)

    except Exception as e:
        logger.error("Could not send gauge %s: %s", metric_name, e.message)
        raise e

# Main method invocation
if __name__ == "__main__":
    publishMetrics("foo", 17, logging.getLogger('general-stats-adapter'))
