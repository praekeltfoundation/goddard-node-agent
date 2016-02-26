#!/usr/bin/python
import io
import sys
import json


# get the node info
node_info_obj = None 

# try to parse it out
try:

  # try to read as a file
  f = open('/var/goddard/node.json', 'r')

  # get the contents
  file_content_str = str(f.read())

  # parse as JSON object
  node_info_obj = json.loads( file_content_str )

  # close the handler
  f.close()

except Exception, e: pass

# define the array to output
cached_whitelist = []

# if we found the node object
if node_info_obj != None:

  # add all the domains
  for whitelist_obj in node_info_obj['whitelist']:

    # add the domain
    cached_whitelist.append( '.' + str(whitelist_obj['domain']) )

# output as file
print '\n'.join(cached_whitelist)
