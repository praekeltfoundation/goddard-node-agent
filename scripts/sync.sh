#!/bin/bash

# echo now
echo "Starting to pull down new media"

# done
echo "{
  \"build\":\"busy\",
  \"process\":\"Starting to download media cache\",
  \"timestamp\":\"$(date +%s)\"
}" > /var/goddard/build.json

# post to server
curl \
  --silent \
  -X POST \
  -d @/var/goddard/build.json \
  http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') \
  --header "Content-Type:application/json"

# refresh the folder sizes before the rsync
du -ach /var/goddard/media > /var/goddard/media_du_human.log
du -ac /var/goddard/media > /var/goddard/media_du_machine.log

# remove the old rsync log file if it exists
rm /var/goddard/media_rsync.log || true

# execute script to pull down new media using Rsync
rsync \ 
  -aPzri \
  --delete \
  --progress \
  --log-file=/var/goddard/media_rsync.log \
  node@hub.goddard.unicore.io:/var/goddard/media/ \
  /var/goddard/media

# refresh the folder sizes after the rsync
du -ach /var/goddard/media > /var/goddard/media_du_human.log
du -ac /var/goddard/media > /var/goddard/media_du_machine.log

# done
echo "{
  \"build\":\"busy\",
  \"process\":\"Media cache finished downloading\",
  \"timestamp\":\"$(date +%s)\"
}" > /var/goddard/build.json

# post to server
curl \
  --silent \
  -X POST \
  -d @/var/goddard/build.json \
  http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') \
  --header "Content-Type:application/json"

# debug
echo "Done pulling media with script"
