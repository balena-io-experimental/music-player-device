sntp = require('sntp')
through = require('through')
Throttle = require('throttle')
stream = require('stream')

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

CHANNELS = 2
BIT_DEPTH = 16
SAMPLE_SIZE = BIT_DEPTH / 8 # bytes per Int16
FRAME_SIZE = SAMPLE_SIZE * CHANNELS
RATE = 44100
BYTE_PER_SEC = RATE * FRAME_SIZE
BYTE_PER_MSEC = BYTE_PER_SEC / 1000
# Maximum accepted deviation from ideal timing
EPSILON_MS = 20
EPSILON_BYTES = EPSILON_MS * BYTE_PER_MSEC

interpolate = (chunk, newLength) ->
	# 3 - linear interpolation

	if newLength <= 0
		return new Buffer(0)

	chunkLength = chunk.length

	n = chunkLength / FRAME_SIZE - 1
	m = newLength / FRAME_SIZE - 1
	newChunk = new Buffer(newLength)
	z = 0
	for i in [0...m]
		t = i / m
		k = t * n | 0
		mu = t * n - k
		for c in [0...CHANNELS]
			xPrev = chunk.readInt16LE(k * FRAME_SIZE + c * SAMPLE_SIZE)
			xNext = chunk.readInt16LE((k + 1) * FRAME_SIZE + c * SAMPLE_SIZE)
			interpolated = xNext * mu + xPrev * (1 - mu) | 0
			newChunk.writeInt16LE(interpolated, z)
			z += SAMPLE_SIZE
	chunk.copy(newChunk, newLength - FRAME_SIZE, chunkLength - FRAME_SIZE)

	newChunk

module.exports.timeKeeper = (start) ->
	actualBytes = 0
	#chunkCount = 0

	return through (chunk) ->
		now = currentTimeSync()
		# Initialise start at the first chunk of data
		if not start?
			start = now + 300

		# Derive the bytes that should have been processed if there was no time skew
		dt = now - start
		idealBytes = dt * BYTE_PER_MSEC

		#chunkCount += 1
		#console.log "#{(chunkCount * 1000 / dt).toFixed(2)} chunks / sec"

		diffBytes = actualBytes - idealBytes
		chunkLength = chunk.length
		actualBytes += chunkLength

		diffMsec = diffBytes / BYTE_PER_MSEC
		console.log('Time deviation:', diffMsec.toFixed(2) + 'ms')

		#diffMsec += 300
		#diffBytes = diffMsec * BYTE_PER_MSEC

		# Only correct the stream if we're out of the EPSILON region
		if -EPSILON_BYTES < diffBytes < EPSILON_BYTES
			correctedChunk = chunk
		else
			console.log('Epsilon exceeded! correcting')
			# The buffer size should be a multiple of 4
			diffBytes = diffBytes - (diffBytes % 4)
			correctedChunk = interpolate(chunk, chunk.length + diffBytes)

		@queue(correctedChunk)
