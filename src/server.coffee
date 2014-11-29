config = require './config'
Playlist = require './playlist'
{ log, logLevel: lvl, readConfigEnvVars, startNtp } = require './util'

readConfigEnvVars()

new Playlist(config.firebaseUrl)

log(lvl.release, 'Running.')
