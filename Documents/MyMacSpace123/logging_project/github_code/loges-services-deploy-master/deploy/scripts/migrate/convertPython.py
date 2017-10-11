#!/usr/bin/python3

import sys, getopt
import json
from pprint import pprint

def create_Bulk(inputfile,outputfile):
    with open(inputfile, 'r+', encoding='utf-8') as data_file:
        data = json.load(data_file)
        n = data["hits"]["total"]
        with open(outputfile, 'w') as outfile:
            for counter in range(0,n):
                j_id = { "index": {"_type" : data["hits"]["hits"][counter]["_type"], "_id" : data["hits"]["hits"][counter]["_id"]}}
                outfile.write(json.dumps(j_id)+'\n')
                outfile.write(json.dumps(data["hits"]["hits"][counter]["_source"]) +'\n')
        outfile.close()
    data_file.close()



def main(argv):
   inputfile = ''
   outputfile = ''
   try:
      opts, args = getopt.getopt(argv,"hi:o:",["ifile=","ofile="])
   except getopt.GetoptError:
      print ('test.py -i <inputfile> -o <outputfile>')
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print ('test.py -i <inputfile> -o <outputfile>')
         sys.exit()
      elif opt in ("-i", "--ifile"):
         inputfile = arg
      elif opt in ("-o", "--ofile"):
         outputfile = arg
   print ('Working on input file ', inputfile)
   print ('with output file ', outputfile)
   create_Bulk(inputfile,outputfile)

if __name__ == "__main__":
   main(sys.argv[1:])

