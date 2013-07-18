Http = require('http')
Lame = require('lame')
Speaker = require('speaker')
GS = require('grooveshark-streaming')

Music =
	queue: []
	now_playing: false

	getStream: (song_name, callback) -> # Searching for song_name on Grooveshark
		console.log("'#{song_name}': Getting SongID.")
		GS.Tinysong.getSongInfo(song_name, '', (err, info) => # Second param for artist_name but it is not separated from song_name yet
			if info is null # Not found
				console.log("'#{song_name}': SongID not found.")
				callback(true, null)
				return
			console.log("'#{song_name}': Got SongID '#{info.SongID}'.")

			console.log("'#{song_name}': Getting stream_url.")
			GS.Grooveshark.getStreamingUrl(info.SongID, (err, stream_url) =>
				console.log("'#{song_name}': Got stream_url '#{stream_url}.'")
				callback(err, stream_url)
			)
		)

	play: ->
		console.log("Music.play(): Checking if playing now or no song in queue.")
		if @now_playing or @queue.length is 0
			console.log("Music.play(): Playing now or no song in queue.")
			return
		console.log("Music.play(): Can play.")

		@now_playing = true
		song = @queue.shift() # Getting the next song_name
		console.log("Music.play(): Got song.name '#{song.name}' and song.start_time '#{song.start_time}'.")

		@getStream(song.name, (err, stream_url) =>
			if err # Could not fetch stream_url
				console.log("#{song.name}: Setting now_playing false.")
				@now_playing = false
				console.log("#{song.name}: Set now_playing false.")
				return

			request = Http.get(stream_url) # Getting stream data
			decoder = new Lame.Decoder()
			stream = null

			request.on('close', => # Stream data have been downloaded
				@now_playing = false
				console.log("'#{song.name}': Closing stream.")
				stream.end()
				console.log("'#{song.name}': Closed stream.")
				@play()
			)
			request.on('response', (stream_data) => # Downloading stream data
				console.log("'#{song.name}': Piping to decoder.")
				stream = stream_data.pipe(decoder)
				console.log("'#{song.name}': Piped to decoder.")

				stream.on('format', (format) =>
					wait = song.start_time - new Date().getTime() # Milliseconds
					console.log("'#{song.name}': Waiting #{wait}s to sync with all devices.")
					setTimeout(=>
						console.log("'#{song.name}': Piping to speaker.")
						stream.pipe(new Speaker(format)) # Playing music
						console.log("'#{song.name}': Piped to speaker.")
					, wait)
				)
			)
		)

module.exports = Music
