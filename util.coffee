sntp = require 'sntp'
through = require 'through'

config = require './config'

currentTimeSync = ->
	sntp.now()

module.exports = {
	currentTimeSync

	startSntp: (callback) ->
		# Refresh clock sync every 5 minutes.
		sntp.start(clockSyncRefresh: 5 * 60 * 1000, callback)

	timeKeeper: (start) ->
		actualBytes = 0

		return through (chunk) ->
			# Note: Javscript dates are expressed in *ms* since epoch.
			now = currentTimeSync()

			# Determine bytes of PCM data per ms of music.
			{ bitDepth, channels, sampleRate } = config.format
			bytesPerMs = sampleRate * channels * (bitDepth / 8) / 1000

			# Maximum accepted deviation from ideal timing (ms.)
			{ maxSkew } = config
			maxSkewBytes = bytesPerMs * maxSkew

			# Determine how far off expectation the stream is.
			idealBytes = (now - start) * bytesPerMs
			diffBytes = actualBytes - idealBytes
			diffBytes -= diffBytes % 4 # Buffer is 4-byte aligned.

			if -maxSkewBytes < diffBytes < maxSkewBytes
				correctedChunk = chunk
			else
				console.log('Maximum skew exceeded! Correcting.')
				correctedChunk = new Buffer(chunk.length + diffBytes)
				chunk.copy(correctedChunk)

			actualBytes += chunk.length

			@emit('data', correctedChunk)
}
