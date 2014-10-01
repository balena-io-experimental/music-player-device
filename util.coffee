_ = require 'lodash'
sntp = require 'sntp'
through = require 'through'

config = require './config'

# E.g. 'fooBarBaz' -> 'FOO_BAR_BAZ'. Leading char must be lowercase.
camelToSnakeCase = (str) -> str.replace(/([A-Z])/g, '_$1').toUpperCase()

parseEnvVal = (val) ->
	return if !val?
	n = parseFloat(val)
	return if isNaN(n) then val else n

currentTimeSync = ->
	sntp.now()

module.exports = {
	currentTimeSync

	readConfigEnvVars: ->
		# Read environment variables with SNAKE_CASE names and assign to config
		# in camelCase.
		_.assign config, _.mapValues config, (val, name) ->
			str = process.env[camelToSnakeCase(name)]
			return parseEnvVal(str) ? val

		console.log('Configuration:', config)

	startSntp: (callback) ->
		# Refresh clock sync every 5 minutes.
		sntp.start(clockSyncRefresh: 5 * 60 * 1000, callback)

	timeKeeper: (start, format) ->
		actualBytes = 0

		return through (chunk) ->
			# Note: Javscript dates are expressed in *ms* since epoch.
			now = currentTimeSync()

			# Determine bytes of PCM data per ms of music.
			{ bitDepth, channels, sampleRate } = format
			bytesPerMs = sampleRate * channels * (bitDepth / 8) / 1000

			# Maximum accepted deviation from ideal timing (ms.)
			maxSkewBytes = bytesPerMs * config.maxSkew

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
