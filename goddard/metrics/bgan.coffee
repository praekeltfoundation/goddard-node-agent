###
# Assembles information about the available hard drive space on the system
###
module.exports = exports = (params, fn) ->

	# get all the metrics
	bgan = require('hughes-bgan');
	bgan.metrics({
		host: params.constants.bgan.ip,
		port: 1829,
		# does this also require a fallback?
		password: 'admin'
	}, (err, res) ->
		return fn(err) if err

		# ensure the metrics are real!
		try
			parsed_obj = JSON.parse(res)
		catch e
			fn(new Error('Could not parse response ...'), {})

		output_obj = {
			faults: parsed_obj.faults or 0,
			ethernet: parsed_obj.ethernet is 1,
			usb: parsed_obj.usb is 1,
			signal: parsed_obj.signal or 0,
			temp: parsed_obj.temp or 0,
			imsi: parsed_obj.imsi or null,
			imei: parsed_obj.imei or null,
			ip: parsed_obj.ip or null,
			satellite_id: parsed_obj.satellite_id or null
		}

		if parsed_obj.gps
			output_obj.lat = parsed_obj.gps.lat or null
			output_obj.lng = parsed_obj.gps.lon or null
			output_obj.status = parsed_obj.gps.status or null

		# done
		fn(null, {bgan: output_obj})
	)
