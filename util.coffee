_ = require 'lodash'
sntp = require 'sntp'

config = require './config'

# E.g. 'fooBarBaz' -> 'FOO_BAR_BAZ'. Leading char must be lowercase.
camelToSnakeCase = (str) -> str.replace(/([A-Z])/g, '_$1').toUpperCase()

parseEnvVal = (val) ->
	return if !val?
	n = parseFloat(val)
	return if isNaN(n) then val else n

module.exports =
	currentTimeSync: sntp.now

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
