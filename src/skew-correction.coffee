through = require 'through'

config = require './config'
{log, logLevel: lvl } = require './util'

# https://en.wikipedia.org/wiki/Exponential_smoothing#The_exponential_moving_average
expSmooth = (factor) ->
	prev = null
	s = null
	return (x) ->
		if s is null
			s = prev = x
			return 0
		else
			s = factor * prev + (1 - factor) * s
			prev = x
			return s

module.exports = (start, format) ->
	actualBytes = 0
	idealBytes = 0

	{ maxSkew, debugMode, smoothFactor } = config

	# Determine bytes of PCM data per ms of music.
	{ bitDepth, channels, sampleRate } = format
	bytesPerMs = sampleRate * channels * (bitDepth / 8) / 1000

	# Maximum accepted deviation from ideal timing (ms.)
	maxSkewBytes = bytesPerMs * maxSkew

	smooth = expSmooth(smoothFactor)

	return through (chunk) ->
		# Determine how far off expectation the stream is.
		idealBytes = (Date.now() - start) * bytesPerMs
		diffBytes = smooth(actualBytes - idealBytes)
		diffBytes -= diffBytes % 4 # Buffer is 4-byte aligned.

		if debugMode
			diffMs = diffBytes / bytesPerMs
			log(lvl.debug, "Delta: #{diffBytes} (#{diffMs.toFixed(2)}ms.)")

		# Note that we count actual bytes *of data processed* not actual bytes
		# piped out as we may remove or add data to output below.
		actualBytes += chunk.length

		# Do not adjust if we're inside skew boundaries or during first 2sec
		if -maxSkewBytes < diffBytes < maxSkewBytes
			return @emit('data', chunk)

		# Skew detected.
		log(lvl.debug, "Exceeds maximum skew of #{maxSkewBytes} (#{maxSkew}ms.)")

		# The correctedChunk buffer has its length reduced or extended depending on
		# whether we're correcting an underrun or an overrun respectively, causing the
		# song to fast-forward or delay respectively

		# If the underrun is so severe that we can't catch up in this chunk,
		# chunk.length + diffBytes will be <= 0. This results in a 0-size buffer
		correctedChunk = new Buffer(chunk.length + diffBytes)
		correctedChunk.fill(0)
		chunk.copy(correctedChunk)

		@emit('data', correctedChunk)
