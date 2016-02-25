#! /bin/sh

# listen for any issues
set -e

# don't run if already setup
if [ ! -f "/var/goddard/proxy.lock" ]; 
  then

  # update apt first
  sudo apt-get update

  # install squid 
  sudo apt-get install squid -y

  # update the config
  cp templates/squid.conf /etc/squid3/squid.conf

  # create the error folder
  mkdir -p /etc/squid3/errors/

  # copy over the acl script
  cp templates/acl.py /var/goddard/acl.py

  # copy over our error page
  cp templates/error.accessdenied.html /etc/squid3/errors/ERR_ACCESS_DENIED

  # verify that the config is correct before restarting
  /usr/sbin/squid3 -k parse

  # restart the squid instance to load new config
  service squid3 restart

  # write our log file
  date > /var/goddard/proxy.lock

fi

####
# TODO update mikrotik
# Run the following:
# /ip hotspot user profile set 0 transparent-proxy=yes
# /ip proxy set enabled=yes
# /ip proxy set parent-proxy=192.168.88.50 set parent-proxy-port=3128
# remove the whitelist
# add the new walled garden entries
###