#!/bin/bash

# echo now
echo "Updating the agent"

# done
echo "{
  \"build\":\"busy\",
  \"process\":\"Self updating the agent\",
  \"timestamp\":\"$( date +%s )\"
}"  > /var/goddard/build.json

# post to server
curl --silent -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

# execute script to pull down new media using Rsync
rsync -aPzri --progress node@hub.goddard.unicore.io:/var/goddard/agent/ /var/goddard/agent

# done
echo "{
  \"build\":\"done\",
  \"process\":\"Node Agent was updated without problems\",
  \"timestamp\":\"$( date +%s )\"
}"  > /var/goddard/build.json

# post to server
curl --silent -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

# debug
echo "Updating agent"
