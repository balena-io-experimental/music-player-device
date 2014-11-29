_ = require 'lodash'

{ exec } = require 'child_process'

config = require './config'

# E.g. 'fooBarBaz' -> 'FOO_BAR_BAZ'. Leading char must be lowercase.
camelToSnakeCase = (str) -> str.replace(/([A-Z])/g, '_$1').toUpperCase()

parseEnvVal = (val) ->
	return if !val?
	n = parseFloat(val)
	return if isNaN(n) then val else n

# Log level.
lvl =
	debug: 1
	release: 2
	error: 3

# Have to bind the 'this' object to console or these functions cry.
logOut = _.bind(console.log, console)
logErr = _.partial(_.bind(console.error, console), 'Error:')

log = (logLevel, args...) ->
	return if logLevel is lvl.debug and !config.debugMode

	print = if logLevel is lvl.error then logErr else logOut
	return print(args...)

module.exports = {
	capitalise: (str) ->
		return str if typeof str isnt 'string'

		return (' ' + str)
			.replace(/\s+([a-z])/g, (chr) -> chr.toUpperCase())
			.trimLeft()

	currentTimeSync: Date.now

	log

	logLevel: lvl

	readConfigEnvVars: =>
		# Read environment variables with SNAKE_CASE names and assign to config
		# in camelCase.
		_.assign config, _.mapValues config, (val, name) ->
			str = process.env[camelToSnakeCase(name)]
			return parseEnvVal(str) ? val

		log(lvl.debug, 'Configuration:', config)

	updateNtp: (callback) ->
		exec "ntpdate #{config.ntpServer}", (err, stdout, stderr) ->
			log(lvl.release, 'ntp server error:', err) if err?
			log(lvl.debug, 'ntpdate', stdout, stderr)

			# Ignore errors, we don't want to disrupt playback *altogether*
			# because NTP failed.
			callback()
}
