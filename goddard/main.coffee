###
# Goddard Agent
# That runs on a cron job
# to configure the node and 
# send metrics back up to the 
# hub
###

# modules
fs = require('fs')

local_settings = ->
	contents = fs.readFileSync(
    '/var/goddard/node_updater/local_settings.py'
  ).toString('utf8')
  lines = contents.trim().split('\n')
  settings = {}
  lines.forEach((line, arr, idx) ->
  	line = line.split('=').map((setting) ->
  		return setting.trim()
  	)
  	settings[line[0]] = line[1].slice(1, -1)
  )
  return settings

# parse the parameters
argv = require('minimist')(process.argv.slice(2))

# check for the type
if argv.action

	# generate the params
	runParams = {
		uid: '',
		constants: require('./constants'),
		node: {},
		argv: argv
		local_settings: local_settings()
	}

	# check if we know it ?
	if argv.action == 'metrics'

		# read in our details
		fs.readFile '/var/goddard/node.json', (err, data) ->

			# was there a problem ?
			if err
				console.dir err 
				process.exit(1)
			else
				# get the params
				param_objs = JSON.parse(data)

				# add in the uid
				runParams.uid = param_objs.uid
				runParams.node = param_objs

				# get the metric function
				metricsRun = require('./metrics')

				# run and get our details
				metricsRun(runParams, (err, payload) ->

					# output when we are done
					# with the payload coming out
					console.dir payload

					# ensure exit
					process.exit(0)

				)
	else if argv.action == 'configure'
		# get the config function
		configRun = require('./config')
		# get it going
		configRun(runParams, (err) -> 

			# debugging
			console.log 'done'

			# ensure exit
			process.exit(0)
		)
	else
		console.log 'Unknown --action flag.'

else
	console.log 'Missing the --action flag'


