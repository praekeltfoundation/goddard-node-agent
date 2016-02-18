#!/bin/bash

# mark as executable
chmod a+x scripts/setup.sh

# echo now
echo "Starting provision service that will run every few hours/minutes to provision apps"

last_ret_code=0

# continues while loop
while :
do

	# debug
	echo "kill all previous runs that are still active of setup"

	# kill the running instance
	pkill -15 -f setup.sh

	# debug
	echo "Delete setup lock, if any ..."

	# deletes the setup lock if any
	rm /var/goddard/setup.lock || true

	# debug
	echo "Running setup script"
	
	# mark as executable (because something might have changed that...)
	chmod a+x scripts/setup.sh	

	# execute command and update status code for done
	./scripts/setup.sh $last_ret_code

	# get the code
	ret_code=$?
	last_ret_code=$ret_code

	# debug
	echo "Setup script is done running"

	# check if the exit code was a 1, so 0 ...
	if [ "$ret_code" -lt 1 ]; then

		# debug
		echo "Setup script was successful, sleeping for 2 hours"

		# sleep for 2 hours then
		sleep 120m

	else

		# debug
		echo "Setup script failed, sleeping for 15 minute then trying again"

		# sleep for 15 minutes
		sleep 15m

	fi

done
