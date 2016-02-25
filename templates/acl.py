#!/usr/bin/python
import io
import sys
import json

###
# cached version of the website
# so we can avoid loading it everytime ...
###
cached_whitelist=[]

# keep looping while waiting for input from Squid
while True:
  # read in the information from squid
  line = sys.stdin.readline().strip()


  if line:

    """
    # debugging
    f = open('/var/goddard/acl.txt', 'a')
    f.write( str(line) + '\n' )
    f.close()
    """

    # get the whitelisted domains
    if len(cached_whitelist) == 0:

      # awesome so read in the whitelist with a few of our own defaults as well
      cached_whitelist = [

        'captive.apple.com', 
        'clientconnectivitycheck.android.com', 
        'clients3.google.com'

      ]

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

      # if we found the node object
      if node_info_obj == None:

        # set to empty again to retry the next time
        cached_whitelist = []

      else:

        # add all the domains
        for whitelist_obj in node_info_obj['whitelist']:

          # add the domain
          cached_whitelist.append( whitelist_obj['domain'] )

    # output to send out to Squid
    filter_output_str = 'ERR'

    # check if in the input
    for whitelist_str in cached_whitelist:
      if whitelist_str in str( line ).lower():
        filter_output_str = 'OK'
        break

    # handle the output
    print filter_output_str
    sys.stdout.flush()
  else:
    print "ERR"
    sys.stdout.flush()