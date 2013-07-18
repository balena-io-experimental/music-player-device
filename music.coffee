Http = require('http')
Lame = require('lame')
Speaker = require('speaker')
GS = require('grooveshark-streaming')

Music =
	queue: []
	now_playing: false

	getStream: (song, callback) -> # Searching for song_name on Grooveshark
		console.log("'#{song.artist} - #{song.name}': Getting SongID.")
		GS.Tinysong.getSongInfo(song.name, song.artist, (err, info) => # Getting SongID
			if info is null # Not found
				console.log("'#{song.artist} - #{song.name}': SongID not found.")
				callback(true, null)
				return
			console.log("'#{song.artist} - #{song.name}': Got SongID '#{info.SongID}'.")

			console.log("'#{song.artist} - #{song.name}': Getting stream_url.")
			GS.Grooveshark.getStreamingUrl(info.SongID, (err, stream_url) =>
				console.log("'#{song.artist} - #{song.name}': Got stream_url '#{stream_url}.'")
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
		console.log("Music.play(): Got", song)

		@getStream(song, (err, stream_url) =>
			if err # Could not fetch stream_url
				console.log("#{song.artist} - #{song.name}: Setting now_playing false.")
				@now_playing = false
				console.log("#{song.artist} - #{song.name}: Set now_playing false.")
				return

			request = Http.get(stream_url) # Getting stream data
			decoder = new Lame.Decoder()
			stream = null

			request.on('close', => # Stream data have been downloaded
				@now_playing = false
				console.log("'#{song.artist} - #{song.name}': Closing stream.")
				stream.end()
				console.log("'#{song.artist} - #{song.name}': Closed stream.")
				@play()
			)
			request.on('response', (stream_data) => # Downloading stream data
				console.log("'#{song.artist} - #{song.name}': Piping to decoder.")
				stream = stream_data.pipe(decoder)
				console.log("'#{song.artist} - #{song.name}': Piped to decoder.")

				stream.on('format', (format) =>
					interval = setInterval(->
						time_remaining = song.start_time - Date.now()
						if time_remaining < 0
							console.log("'#{song.artist} - #{song.name}': Should be playing now.")
							clearInterval(interval)
						else
							console.log("'#{song.artist} - #{song.name}': Waiting #{time_remaining / 1000}s to sync with all devices.")
					, 1000)

					setTimeout(=>
						console.log("'#{song.artist} - #{song.name}': Piping to speaker.")
						stream.pipe(new Speaker(format)) # Playing music
						console.log("'#{song.artist} - #{song.name}': Piped to speaker.")
					, song.start_time - Date.now())
				)
			)
		)

module.exports = Music
