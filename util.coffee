sntp = require('sntp')
through = require('through')
Throttle = require('throttle')
stream = require('stream')

config = require('./config')

module.exports.startSntp = (cb) ->
	sntp.start(clockSyncRefresh: 5 * 60 * 1000, cb)

module.exports.currentTime = (cb) ->
	sntp.time (err, time) ->
		if err
			cb(null, Date.now())
			console.error "SNTP Error", err
			return

		cb(null, Date.now() + time.t)

module.exports.currentTimeSync = currentTimeSync = ->
	sntp.now()

module.exports.timeKeeper = ->
	start = null

	# State variables
	actualBytes = 0

	# The actual stream processing function
	return through (chunk) ->

		# Initialise start the at the first chunk of data
		if start is null
			start = currentTimeSync()

		now = currentTimeSync()

		{ bitDepth, channels, sampleRate } = config.format

		byteMul = sampleRate * channels * (bitDepth / 8)

		# Maximum accepted deviation from ideal timing
		EPSILON_MS = 200
		EPSILON_BYTES = (EPSILON_MS / 1000) * byteMul

		# Derive the bytes that should have been processed if there was no time skew

		# now, start are ms.
		idealBytes = (now - start)/1000 * byteMul
		diffBytes = actualBytes - idealBytes

		actualBytes += chunk.length
		#console.log('Time deviation:', (diffBytes / byteMul).toFixed(2) + 'ms')

		# The buffer size should be a multiple of 4
		diffBytes = diffBytes - (diffBytes % 4)

		# Only correct the stream if we're out of the EPSILON region.
		if -EPSILON_BYTES < diffBytes < EPSILON_BYTES
			correctedChunk = chunk
		else
			console.log('Epsilon exceeded! correcting')
			correctedChunk = new Buffer(chunk.length + diffBytes)
			chunk.copy(correctedChunk)

		@emit('data', correctedChunk)
