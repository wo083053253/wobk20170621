#!/usr/bin/python
import optparse
import logging
from lib import EsLib

if __name__ == '__main__':

    logLevel = logging.INFO
    usage = "usage: %prog [options]\n where: \n\t\quota : the quota in gb for estimate.\n"
    parser = optparse.OptionParser(usage=usage)
    parser.add_option('-t','--tenant', dest='tenant', help='Tenant space id')
    parser.add_option('-q','--quota', dest='quota', help='quota in gb for emstimate')
    parser.add_option('--debug', action='store_true', dest='debug', default=False, help='Enable additional debugging of the install script')
    parser.add_option('--logFile', dest='logFile', metavar='FILE', default='trace.log', help='Name of the trace log file (default trace.log)')

    ( options, args ) = parser.parse_args();

    if options.debug == True :
        logLevel = logging.DEBUG

    logger = logging.basicConfig(filename=options.logFile,level=logLevel)
    logger = logging.getLogger("esutils.py")
    logger.info('----------------------------------------------------------------')
    logger.info("Starting ")

    if options.tenant == None :
        eslib=EsLib(logger)
        clusters=eslib.getEsClusterList()
        for cluster in clusters:
          eslib.populateCluster(cluster)
        eslib.printEsClusterStatus(clusters)
        exit(0)

    if options.quota == None :
        msg = "Please Provide quota in GB for estimate."
        logger.error(msg)
        print(msg)
        exit(-1)

    eslib=EsLib(logger)
    te=eslib.getTenantEstimate(options.tenant, options.quota)
    eslib.printTenantEstimate(te)
    exit(0)
