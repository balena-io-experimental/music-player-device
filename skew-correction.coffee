through = require 'through'

config = require './config'
{ currentTimeSync } = require './util'

module.exports = (start, format) ->
	actualBytes = 0

	return through (chunk) ->
		{ maxSkew, debugMode } = config

		# Note: Javscript dates are expressed in *ms* since epoch.
		now = currentTimeSync()

		# Determine bytes of PCM data per ms of music.
		{ bitDepth, channels, sampleRate } = format
		bytesPerMs = sampleRate * channels * (bitDepth / 8) / 1000

		# Maximum accepted deviation from ideal timing (ms.)
		maxSkewBytes = bytesPerMs * maxSkew

		# Determine how far off expectation the stream is.
		idealBytes = (now - start) * bytesPerMs
		diffBytes = actualBytes - idealBytes
		diffBytes -= diffBytes % 4 # Buffer is 4-byte aligned.

		if debugMode
			diffMs = diffBytes / bytesPerMs
			console.log("Delta: #{diffBytes} (#{diffMs.toFixed(2)}ms.)")

		actualBytes += chunk.length

		return @emit('data', chunk) if -maxSkewBytes < diffBytes < maxSkewBytes

		# Skew detected.

		if debugMode
			console.log("Exceeds maximum skew of #{maxSkewBytes} (#{maxSkew}ms.)")

		correctedChunk = new Buffer(chunk.length + diffBytes)
		chunk.copy(correctedChunk)

		@emit('data', correctedChunk)
