#! /bin/sh

# listen for any issues
set -e

# don't run if already setup
if [ ! -f "/var/goddard/proxy.lock" ]; 
  then

  # update apt first
  sudo apt-get update

  # install squid 
  sudo apt-get install squid sshpass -y

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

  # pull out the password for the 750
  ROUTER_PASSWORD=$(python -c "import imp; localsettings=imp.load_source('localsettings', '/var/goddard/node_updater/local_settings.py'); print localsettings.NEW_RB750_PASSWORD")

  # debug
  echo "Found Password: $ROUTER_PASSWORD" 

  # run the commands to migrate changes over to mikrotik
  sshpass -p "$ROUTER_PASSWORD" ssh admin@192.168.88.5 "$(which bash) -s" << EOF
      /ip hotspot user profile set 0 transparent-proxy=yes
      /ip proxy set enabled=yes
      /ip proxy set parent-proxy=192.168.88.50 set parent-proxy-port=3128
      /ip hotspot walled-garden remove numbers=[/ip hotspot walled-garden find ]
      /ip hotspot walled-garden add action=deny dst-host=192.168.88.5 server=hotspot1
      /ip hotspot walled-garden add action=deny dst-host=192.168.88.10 server=hotspot1
      /ip hotspot walled-garden add action=deny dst-host=192.168.88.50 server=hotspot1
      /ip hotspot walled-garden add action=allow dst-host=* server=hotspot1
  EOF

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