{FIREBASE_URL} = require('./config')
Playlist = require('./playlist')
{startSntp} = require('./lib/util')

# run
startSntp ->
	new Playlist(FIREBASE_URL)

	console.log '\n\n\nRunning'
