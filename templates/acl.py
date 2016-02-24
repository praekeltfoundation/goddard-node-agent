#!/usr/bin/python
import io
import sys

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
    # debugging
    f = open('/var/goddard/acl.txt', 'a')
    f.write( str(line) + '\n' )
    f.close()

    # get the whitelisted domains
    if len(cached_whitelist) == 0:

      # load in the whitelist
      cached_whitelist = [ 'opera', 'io.co.za', 'reddit.com', 'captive.apple.com', 'clientconnectivitycheck.android.com', 'clients3.google.com' ]

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