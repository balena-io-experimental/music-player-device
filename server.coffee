config = require './config'
Playlist = require './playlist'
{ log, logLevel: lvl, readConfigEnvVars, startSntp } = require './util'

readConfigEnvVars()

startSntp ->
	new Playlist(config.firebaseUrl)

	log(lvl.release, 'Running.')
