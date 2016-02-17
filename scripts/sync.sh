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

# refresh the folder sizes BEFORE the rsync
du --max-depth=5 -c -h /var/goddard/media > /var/goddard/media_sizes.log

# remove the old rsync log file if it exists
rm /var/goddard/media_sync.log || true

# execute script to pull down new media using Rsync
rsync \ 
  -aPzri \
  --delete \
  --progress \
  --log-file=/var/goddard/media_sync.log \
  node@hub.goddard.unicore.io:/var/goddard/media/ \
  /var/goddard/media

# refresh the folder sizes AFTER the rsync
du --max-depth=5 -c -h /var/goddard/media > /var/goddard/media_sizes.log

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
