Firebase = require 'firebase'
Playlist = require './playlist'

PLAY_DELAY = 15000

playlist = new Playlist()

commands =
	play: (artist, song, time) ->
		entry =
			name: song
			artist: artist
			start_time: time + PLAY_DELAY

		playlist.push(entry)
		console.log("'#{entry.artist} - #{entry.name}': Added to queue.")

		# Start playing the queue or do nothing if already playing
		playlist.play()

	skip: (text, time) ->
		if playlist.length isnt 0
			playlist[0].start_time = Date.now() + 3000 + PLAY_DELAY
		playlist.skip()

db = new Firebase('https://sonos.firebaseio.com/')

db.on 'value', (data) ->
	data = data.val()
	if data
		[command, args...] = data
		commands[command]?(args...)
