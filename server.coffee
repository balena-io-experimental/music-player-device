{ firebaseUrl } = require './config'
Playlist = require './playlist'
{ startSntp } = require './util'

startSntp ->
	new Playlist(firebaseUrl)

	console.log 'Running'
