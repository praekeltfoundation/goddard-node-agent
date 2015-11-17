#!/bin/bash
set -e
# double check folder
mkdir -p /var/goddard

# check for a lock
if [ ! -f /var/goddard/setup.lock ]; then

	# write the lock
	echo `date` > /var/goddard/setup.lock

	# done
	echo "{\"build\":\"busy\",\"process\":\"Loading base image\",\"timestamp\":\"$( date +%s )\"}" > /var/goddard/build.json

	# post to server
	curl -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

	# load in the docker image
	docker load < /var/goddard/node.img.tar || true

	# done
	echo "{\"build\":\"busy\",\"process\":\"Downloading app list for node ...\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

	# post to server
	curl -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

	# reload flag
	nginx_reload_flag=0

	# read in all the apps from the server
	curl "http://hub.goddard.unicore.io/apps.json?uid=$(cat /var/goddard/node.json | jq -r '.uid')" > /var/goddard/apps.raw.json

	# register the return code
	ret_code=$?

	# check the code, must be 0
	if [ $ret_code = 0 ]; then

		# check the diff first
		DIFF=$(diff /var/goddard/apps.raw.json /var/goddard/apps.json | cat)
		if [ "$DIFF" != "" ]
		then
			nginx_reload_flag=1
		fi

		# move the json to live node details
		mv /var/goddard/apps.raw.json /var/goddard/apps.json

		# done
		echo "{\"build\":\"busy\",\"process\":\"Downloaded app list for node ...\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

		# post to server
		curl -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

		# awesome start a deploy
		cat /var/goddard/apps.json | jq -r '.[]  | "\(.key) \(.domain) \(.port)"' > /var/goddard/apps.keys.txt

		# cool so now we have the keys
		while read tkey tdomain tport
		do

			# debug
			echo "Downloading application $tdomain"

			# done
			echo "{\"build\":\"busy\",\"process\":\"Downloading application $tdomain\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

			# post to server
			curl -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

			# sync down the code
			amount=$(rsync -aPzri --progress node@hub.goddard.unicore.io:/var/goddard/apps/$tkey/ /var/goddard/apps/$tkey | wc -l)

			# check the amount changed files
			if [ "$amount" -gt 1 ]; then

				# mark as 'yes'
				nginx_reload_flag=1

				# debug
				echo "Building $tdomain"

				# done
				echo "{\"build\":\"busy\",\"process\":\"Building $tdomain\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

				# post to server
				curl -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

				# build the app
				cd /var/goddard/apps/$tkey && docker build --tag="$tkey" --rm=true .

				# done
				echo "Stopping running apps"

				# done
				echo "{\"build\":\"busy\",\"process\":\"Stopping $tkey\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

				# post to server
				curl -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

				# run the docker command
				# docker ps -a -q | grep $tkey

				# stop all the running apps
				# docker kill $(docker ps -a -q | grep $tkey) || true
				docker kill $(docker ps -a | awk '{ print $1,$2 }' | grep $tkey | awk '{print $1 }')

				# start the app
				echo "Starting $tdomain"

				# done
				echo "{\"build\":\"busy\",\"process\":\"Starting $tdomain\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

				# start the app
				docker run --restart=always -p $tport:8080 -d $tkey

			fi

		done < /var/goddard/apps.keys.txt

		# check if the exit code was a 1, so 0 ...
		if [ "$nginx_reload_flag" = 1 ]; then

			# delete the old nginx conf
			rm /etc/nginx/conf.d/*.conf || true

			# write default config
			cat /var/goddard/agent/templates/unknown.html > /var/goddard/index.html
			cat /var/goddard/agent/templates/nginx.static.conf > /etc/nginx/conf.d/default.conf

			# cool so now we have the keys
			while read tkey tdomain tport
			do
				# done
				echo "Adding $tdomain web server config"

				# done
				echo "{\"build\":\"busy\",\"process\":\"Adding $tdomain web server config\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

				# post to server
				curl -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

				# write out the service file
				sudo cat <<-EOF > /etc/nginx/conf.d/$tdomain.conf

					server {

						listen                          80;
						server_name                     $tdomain;
						access_log                      /var/log/nginx/${tkey}.access.log;
						error_log                       /var/log/nginx/${tkey}.error.log;

						location / {

							proxy_pass                  http://127.0.0.1:${tport}\$request_uri;
							proxy_redirect              off;

							proxy_set_header            Host             \$host;
							proxy_set_header            X-Real-IP        \$remote_addr;
							proxy_set_header            X-Forwarded-For  \$proxy_add_x_forwarded_for;
							proxy_max_temp_file_size    0;

							client_max_body_size        10m;
							client_body_buffer_size     128k;

							proxy_connect_timeout       120;
							proxy_send_timeout          1200;
							proxy_read_timeout          120;

							proxy_buffer_size           128k;
							proxy_buffers               4 256k;
							proxy_busy_buffers_size     256k;
							proxy_temp_file_write_size  256k;

						}

					}

				EOF

			done < /var/goddard/apps.keys.txt

			# restart nginx
			service nginx reload || true

		fi

		# done
		echo "{\"build\":\"busy\",\"process\":\"\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

		# update in file
		running_docker_status=$(docker ps)

		# clean up the docker output
		# cleaned_docker_status=$(echo $running_docker_status | sed -r 's/[\"]+/\\\"/g')
		cleaned_docker_status=$(echo -n "$running_docker_status" | python -c 'import json,sys; print json.dumps(sys.stdin.read())')
		echo "{\"build\":\"busy\",\"process\":\"Output from Docker: ${cleaned_docker_status}\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

		# post to server
		curl -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

		# cool so now we have the keys
		while read tkey tdomain tport
		do

			# debug
			echo "Sanity Check if $tkey is actually running"

			# done
			echo "{\"build\":\"busy\",\"process\":\"Making sure $tkey is actually running\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

			# post to server
			curl -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

			# get the running apps
			running_app_container=$(docker ps | grep $tkey) || true

			# check the amount changed files
			if [ "$running_app_container" = "" ]; then

				# make sure we are not double staring a container
				docker kill $(docker ps -a | awk '{ print $1,$2 }' | grep $tkey | awk '{print $1 }') || true

				# start the app
				echo "Starting $tkey as it was not running"

				# done
				echo "{\"build\":\"busy\",\"process\":\"Starting $tkey as it was not running\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

				# start the app
				docker run --restart=always -p $tport:8080 -d $tkey

			fi

		done < /var/goddard/apps.keys.txt

	else

		# done
		echo "{\"build\":\"error\",\"process\":\"Parsing of app.json failed from hub server\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

		# post to server
		curl -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

		# debugging to tell us why
		echo "The json parsing test failed, server returned invalid JSON, the test was done on /var/goddard/apps.raw.json"

		# stop the process
		exit 1

	fi

	# done
	echo "{\"build\":\"done\",\"process\":\"Done\",\"timestamp\":\"$( date +%s )\"}"  > /var/goddard/build.json

	# post to server
	curl -X POST -d @/var/goddard/build.json http://hub.goddard.unicore.io/report.json?uid=$(cat /var/goddard/node.json | jq -r '.uid') --header "Content-Type:application/json"

	# kill the lock
	rm /var/goddard/setup.lock || true

fi
