#!/bin/bash

# echo now
echo "Starting to pull down new media"

# done
echo "{\"build\":\"busy\",\"process\":\"Starting to download media cache\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

# post to server
curl --silent -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

# execute script to pull down new media using Rsync
rsync -aPzri --delete --progress node@hub.goddard.unicore.io:/var/goddard/media/ /var/goddard/media

# done
echo "{
  \"build\":\"done\",
  \"process\":\"Media cache finished downloading\",
  \"timestamp\":\"$( date +%s )\"
}"  > /var/goddard/build.json

# post to server
curl --silent -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

# debug
echo "Done pulling media with script"
