#!/usr/bin/env bash

set -e

GODDARD_BASE_PATH="/var/goddard"
GODDARD_APPS_BASE_PATH="${GODDARD_BASE_PATH}/apps"
LOCK_FILE_PATH="${GODDARD_BASE_PATH}/setup.lock"
BUILD_JSON_PATH="${GODDARD_BASE_PATH}/build.json"
NODE_JSON_PATH="${GODDARD_BASE_PATH}/node.json"
NODE_JSON_RAW_PATH="${GODDARD_BASE_PATH}/node.raw.json"
APPS_JSON_PATH="${GODDARD_BASE_PATH}/apps.json"
APPS_JSON_RAW_PATH="${GODDARD_BASE_PATH}/apps.raw.json"
APPS_KEYS_TXT_PATH="${GODDARD_BASE_PATH}/apps.keys.txt"
NGINX_CONFD_PATH="/etc/nginx/conf.d"
HUB_GODDARD_UNICORE="hub.goddard.unicore.io"

NEW_VIRTUAL_HOST() {
	local VIRTUAL_HOST_PATH="${1}"
	local TDOMAIN="${2}"
	local TKEY="${3}"
	local TPORT="${4}"

	sudo cat <<-EOF > ${VIRTUAL_HOST_PATH}
		server {
			listen                        80;
			server_name                   ${TDOMAIN};
			access_log                    /var/log/nginx/${TKEY}.access.log;
			error_log                     /var/log/nginx/${TKEY}.error.log;
			location / {
				proxy_pass                  http://127.0.0.1:${TPORT}\$request_uri;
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
}

POST_TO_SERVER() {
	declare NODE_UID
	NODE_UID=$(jq -r '.uid' < "${NODE_JSON_PATH}")
	curl \
		-X POST \
		-d "@${BUILD_JSON_PATH}" \
		"http://${HUB_GODDARD_UNICORE}/report.json?uid=${NODE_UID}" \
		--header "Content-Type: application/json"
	echo ""
}

POST_TUNNELING_INFO_TO_SERVER() {
	PUBLIC_KEY=$(cat "/home/goddard/.ssh/id_rsa.pub")
	read -r MAC_ADDRESS < "/sys/class/net/eth0/address"
	curl \
		-X POST \
		-d "{\"mac\": \"${MAC_ADDRESS}\", \"key\": \"${PUBLIC_KEY}\"}" \
		"http://${HUB_GODDARD_UNICORE}/setup.json" > "${NODE_JSON_RAW_PATH}" \
		--header "Content-Type: application/json"
	echo ""
}

POST_BUILD_JSON_BUSY() {
	local PROCESS="${1}"
	echo "${PROCESS}"
	echo "{
		\"build\": \"busy\",
		\"process\": \"${PROCESS}\",
		\"timestamp\": \"$(date +%s)\"
	}" > "${BUILD_JSON_PATH}"
	POST_TO_SERVER
}

POST_BUILD_JSON_ERROR() {
	local ERROR="${1}"
	echo "${ERROR}"
	echo "{
		\"build\": \"error\",
		\"process\": \"${ERROR}\",
		\"timestamp\": \"$(date +%s)\"
	}" > "${BUILD_JSON_PATH}"
	POST_TO_SERVER
}

POST_BUILD_JSON_DONE() {
	echo "{
		\"build\": \"done\",
		\"process\": \"Done\",
		\"timestamp\": \"$(date +%s)\"
	}" > "${BUILD_JSON_PATH}"
	POST_TO_SERVER
}

WRITE_SETUP_LOCK() {
	date > "${LOCK_FILE_PATH}"
}

UNLINK_SETUP_LOCK() {
	rm "${LOCK_FILE_PATH}" || true
}

sudo mkdir -p "${GODDARD_BASE_PATH}"

if [[ -f "${LOCK_FILE_PATH}" ]]; then exit 1; fi

WRITE_SETUP_LOCK
POST_BUILD_JSON_BUSY "Updating node.json with the latest details"
sudo chmod -R 0777 "${GODDARD_BASE_PATH}"
POST_TUNNELING_INFO_TO_SERVER
eval jq -r '.' < "${NODE_JSON_RAW_PATH}"
JQ_RETURN_CODE="${?}"

if [[ "${JQ_RETURN_CODE}" == "0" ]]; then 
	mv "${NODE_JSON_RAW_PATH}" "${NODE_JSON_PATH}"
fi

POST_BUILD_JSON_BUSY "Loading base image"
docker load < "${GODDARD_BASE_PATH}/node.img.tar" || true
POST_BUILD_JSON_BUSY "Downloading app list for node..."
curl "http://${HUB_GODDARD_UNICORE}/apps.json?uid=$(jq -r '.uid' < "${NODE_JSON_PATH}")" > "${APPS_JSON_RAW_PATH}"
CURL_RET_CODE="${?}"

if [[ "${CURL_RET_CODE}" != "0" ]]; then
	POST_BUILD_JSON_ERROR "Parsing of app.json failed from hub server"
	echo "The JSON parsing test failed"
	echo "Server returned invalid JSON"
	echo "The test was done on ${APPS_JSON_RAW_PATH}"
	exit 1
fi

mv "${APPS_JSON_RAW_PATH}" "${APPS_JSON_PATH}"
POST_BUILD_JSON_BUSY "Downloaded app list for node..."
jq -r '.[]  | "\(.key) \(.domain) \(.port)"' < "${APPS_JSON_PATH}" > "${APPS_KEYS_TXT_PATH}"
rm "${NGINX_CONFD_PATH}/*.conf" || true

# do *NOT* quote the argument to docker kill
# the container ids need to be whitespace delimited
docker kill $(docker ps -q) || true

while read TKEY TDOMAIN TPORT; do
	POST_BUILD_JSON_BUSY "Downloading application ${TDOMAIN}"
	echo "diff size: $(rsync -aPzri --progress "node@${HUB_GODDARD_UNICORE}:${GODDARD_APPS_BASE_PATH}/${TKEY}/" "${GODDARD_APPS_BASE_PATH}/${TKEY}" | wc -l)"
	POST_BUILD_JSON_BUSY "Building ${TDOMAIN}"
	cd "${GODDARD_APPS_BASE_PATH}/${TKEY}" && docker build --tag="${TKEY}" --rm=true "."
	POST_BUILD_JSON_BUSY "Stopping ${TKEY}"
	RUNNING_CONTAINERS="$(docker ps)"
	ID_TO_IMAGE=$(echo "${RUNNING_CONTAINERS}" | awk '{print $1, $2}')
	CONTAINER=$(echo "${ID_TO_IMAGE}" | grep "${TKEY}" | cat)
	
	if [[ "${CONTAINER}" == "" ]]; then
		echo "${TKEY} is not running!"
	else
		CONTAINER_ID=$(echo "${CONTAINER}" | awk '{print $1}')
		docker kill "${CONTAINER_ID}"
		echo "done!"
	fi
	
	POST_BUILD_JSON_BUSY "Starting ${TDOMAIN}"
	docker run --restart=always -p "${TPORT}:8080" -d "${TKEY}"
	POST_BUILD_JSON_BUSY "Adding ${TDOMAIN} web server config"
	NEW_VIRTUAL_HOST "${NGINX_CONFD_PATH}/${TDOMAIN}.conf" "${TDOMAIN}" "${TKEY}" "${TPORT}"
done < "${APPS_KEYS_TXT_PATH}"

cat "${GODDARD_BASE_PATH}/agent/templates/unknown.html" > "${GODDARD_BASE_PATH}/index.html"
cat "${GODDARD_BASE_PATH}/agent/templates/nginx.static.conf" > "${NGINX_CONFD_PATH}/default.conf"

service nginx reload || true

POST_BUILD_JSON_DONE

UNLINK_SETUP_LOCK

exit 0
