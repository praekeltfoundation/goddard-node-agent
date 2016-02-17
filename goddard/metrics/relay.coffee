###
# Assembles information about the available hard drive space on the system
###
module.exports = exports = (params, fn) ->

	# require our library to ping
	webrelay = require('webrelay')
	parseString = require('xml2js').parseString
	_ = require('underscore')

	# get the entire state of the relay
	webrelay.state params.constants.relay.ip, (err, res) ->
		console.log('relay error', err) if err

		# check for a error
		if err
			fn(err, {})
		else
			# parse out the XML response from the relay
			parseString res, (err, parsed_result_obj) ->
				console.log('relay error', err) if err
				
				# check for a error
				if err
					fn(err, {})
				else
					# array of relay states
					relay_states_strs = []

					# did we get a response ...
					if parsed_result_obj and parsed_result_obj.datavalues

						# add each
						for relay_key in _.keys( parsed_result_obj.datavalues )

							# add it in
							relay_states_strs.push 1 * parsed_result_obj.datavalues[relay_key]

					# output
					fn(err, {

							relays: relay_states_strs

						})
