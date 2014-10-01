config = require './config'
Playlist = require './playlist'
util = require './util'

util.readConfigEnvVars()

util.startSntp ->
	new Playlist(config.firebaseUrl)

	console.log 'Running'
