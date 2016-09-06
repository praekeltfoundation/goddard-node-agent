#! /bin/sh

# listen for any issues
set -e

RUN_COMMAND() {
  
  # pull out the password for the 750
  ROUTER_PASSWORD=$(python -c "import imp; localsettings=imp.load_source('localsettings', '/var/goddard/node_updater/local_settings.py'); print localsettings.RB750_PASSWORD")
  NEW_ROUTER_PASSWORD=$(python -c "import imp; localsettings=imp.load_source('localsettings', '/var/goddard/node_updater/local_settings.py'); print localsettings.NEW_RB750_PASSWORD")

  # run it with both password to work with all the nodes
  echo "$1" | sshpass -p "$ROUTER_PASSWORD" ssh -o "StrictHostKeyChecking no" admin@192.168.88.5 || true
  echo "$1" | sshpass -p "$NEW_ROUTER_PASSWORD" ssh -o "StrictHostKeyChecking no" admin@192.168.88.5 || true

}

# don't run if already setup
if [ ! -f "/var/goddard/proxy.lock" ]; 
  then

  # just in case the folder does not exist
  mkdir -p /var/cache/apt/archives/

  # download the debs from the server
  rsync -azri --no-perms \
    "node@hub.goddard.unicore.io:/var/goddard/debs/" \
    "/var/cache/apt/archives/"

  # install squid 
  sudo apt-get install -y --force-yes squid sshpass

  # update the config
  cp /var/goddard/agent/templates/squid.conf /etc/squid3/squid.conf

  # create the error folder
  mkdir -p /etc/squid3/errors/

  # copy over the acl script
  cp /var/goddard/agent/templates/acl.py /var/goddard/acl.py

  # copy over our error page
  cp /var/goddard/agent/templates/error.accessdenied.html /etc/squid3/errors/ERR_ACCESS_DENIED

  # verify that the config is correct before restarting
  /usr/sbin/squid3 -k parse

  # create the file
  touch /var/goddard/whitelist

  # restart the squid instance to load new config
  service squid3 restart

  # do a keyscan to be sure we can execute the commands
  ssh-keyscan 192.168.88.5 >> ~/.ssh/known_hosts

  # run the commands to migrate changes over to mikrotik
  RUN_COMMAND "/ip dhcp-server option add name=wpad code=252 value=\"'http://wpad.mamawifi.com:80/wpad.dat'\""
  RUN_COMMAND "/ip dhcp-server network set 0 dhcp-option=wpad"
  RUN_COMMAND "/ip dhcp-server network set 1 dhcp-option=wpad"
  RUN_COMMAND "/ip hotspot walled-garden remove numbers=[/ip hotspot walled-garden find ]"
  RUN_COMMAND "/ip hotspot walled-garden add action=deny dst-host=192.168.88.5 server=hotspot1"
  RUN_COMMAND "/ip hotspot walled-garden add action=deny dst-host=192.168.88.10 server=hotspot1"
  RUN_COMMAND "/ip hotspot walled-garden add action=allow dst-host=192.168.88.50 server=hotspot1"
  RUN_COMMAND "/ip hotspot walled-garden add action=deny dst-host=* server=hotspot1"

  # write our log file
  date > /var/goddard/proxy.lock

fi

# write out the wpad config file
sudo cat <<-EOF > /var/goddard/wpad.dat
  function FindProxyForURL(url, host)
  {
  if (isInNet(host, "192.168.88.0", "255.255.255.0"))
  return "DIRECT";
  else
  return "PROXY 192.168.88.50:3128";
  }
EOF

# get mac addres of network interface
read -r mac < /sys/class/net/eth0/address

# handle the public key
publickey=`cat /home/goddard/.ssh/id_rsa.pub`

# send HTTP POST - including tunnel info
curl -d "{\"mac\": \"${mac}\", \"key\": \"${publickey}\"}" -H "Content-Type: application/json" -X POST http://hub.goddard.unicore.io/setup.json > /var/goddard/node.raw.json

# check if the returned json was valid
eval cat /var/goddard/node.raw.json | jq -r '.'

# register the return code
ret_code=$?

# check the code, must be 0
if [ $ret_code = 0 ]; then

  # move the json to live node details
  mv /var/goddard/node.raw.json /var/goddard/node.json

fi

# update whitelist
python /var/goddard/agent/templates/acl.py > /var/goddard/whitelist

# verify that the config is correct before restarting
/usr/sbin/squid3 -k reconfigure

# reload nginx
service nginx reload || true

####
# TODO update mikrotik
# Run the following:
# /ip hotspot user profile set 0 transparent-proxy=yes
# /ip proxy set enabled=yes
# /ip proxy set parent-proxy=192.168.88.50 set parent-proxy-port=3128
# remove the whitelist
# add the new walled garden entries
###