through = require 'through'

config = require './config'
{log, logLevel: lvl } = require './util'

module.exports = (start, format) ->
	actualBytes = 0
	idealBytes = 0
	lastCorrection = 0
	lastChunkCorrected = false

	{ maxSkew, debugMode } = config

	# Determine bytes of PCM data per ms of music.
	{ bitDepth, channels, sampleRate } = format
	bytesPerMs = sampleRate * channels * (bitDepth / 8) / 1000

	# Maximum accepted deviation from ideal timing (ms.)
	maxSkewBytes = bytesPerMs * maxSkew
	console.log("Bytes per ms", bytesPerMs, "MaxSkewBytes", maxSkewBytes)

	return through (chunk) ->
		# Note: Javscript dates are expressed in *ms* since epoch.
		console.log()
		now = Date.now()

		emit = (corrected, data) =>
			lastChunkCorrected = corrected
			lastCorrection = now if corrected
			console.log("ActualBytes:", actualBytes, "IdealBytes:", idealBytes)
			@emit('data', data)

		# Determine how far off expectation the stream is.
		idealBytes = (now - start) * bytesPerMs
		diffBytes = actualBytes - idealBytes
		diffBytes -= diffBytes % 4 # Buffer is 4-byte aligned.

		if debugMode
			diffMs = diffBytes / bytesPerMs
			log(lvl.debug, "Delta: #{diffBytes} (#{diffMs.toFixed(2)}ms.)")
			checkMs = Date.now() - now
			log(lvl.debug, "Skew check took #{checkMs}ms.")

		# Note that we count actual bytes *of data processed* not actual bytes
		# piped out as we may remove or add data to output below.
		actualBytes += chunk.length

		return emit(false, chunk) if -maxSkewBytes < diffBytes < maxSkewBytes

		# Skew detected.

		log(lvl.debug, "Exceeds maximum skew of #{maxSkewBytes} (#{maxSkew}ms.)")

		# Debounce skew corrections to avoid playback choppiness.
		sinceLastCorrection = now - lastCorrection

		# If last chunk was corrected we shouldn't 'debounce' in order to allow
		# for corrections that cannot be performed in a single chunk.
		# if lastChunkCorrected# and sinceLastCorrection < config.minSkewCorrectionPeriod
		# 	return emit(false, chunk)

		log(lvl.debug, 'Correcting skew.')
		log(lvl.debug, "Last correction #{sinceLastCorrection}ms ago",
			"(#{config.minSkewCorrectionPeriod}ms minimum period.)")

		# We need to take different action depending on whether we're behind
		# (underrun) or ahead (overrun) of the expected playing time.

		# In an underrun we need to effectively fast-forward and output a
		# *smaller* chunk from here to the output.

		# This means less delay in processing the next chunk and thus we 'catch up'.

		# In an overrun, we need to effectively pause and output a *larger*
		# chunk from here to the output.

		# This means more delay before processing the next chunk and thus we
		# allow the data being sent to us to 'catch up'.

		# If the underrun is so severe that we can't catch up in this chunk,
		# chunk.length + diffBytes will be <= 0. This results in a 0-size buffer
		# and we can quit early.
		correctedChunk = new Buffer(chunk.length + diffBytes)
		length = correctedChunk.length
		log(lvl.debug, 'New buffer size:', length)

		return emit(true, correctedChunk) if length == 0

		if diffBytes < 0
			# Underrun.

			# We need to skip the -diffBytes we are behind by. No need to zero
			# as we fill the whole buffer with what remains.
			chunk.copy(correctedChunk)
		else
			# Overrun.

			# Copy the music into the start of the chunk before the 'pause'.
			chunk.copy(correctedChunk)
			# Buffers are *not* zeroed by default so clear out 'paused' portion
			# of buffer to avoid undefined (+ often horrible) sound.
			correctedChunk.fill(0, chunk.length)

		emit(true, correctedChunk)

		if debugMode
			correctMs = Date.now() - checkMs - now
			log(lvl.debug, "Skew correction took #{correctMs}ms.")
