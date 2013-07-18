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
			console.log("'#{song_name}': Got SongID #{info.SongID}")

			console.log("'#{song_name}': Getting stream_url.")
			GS.Grooveshark.getStreamingUrl(info.SongID, (err, stream_url) =>
				console.log("'#{song_name}': Got stream_url #{stream_url}")
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
		song_name = @queue.shift() # Getting the next song_name
		console.log("Music.play(): Got song_name #{song_name}")

		@getStream(song_name, (err, stream_url) =>
			if err # Could not fetch stream_url
				console.log("#{song_name}: Setting now_playing false.")
				@now_playing = false
				console.log("#{song_name}: Set now_playing false.")
				return

			request = Http.get(stream_url) # Getting stream data
			decoder = new Lame.Decoder()
			stream = null

			request.on('close', => # Stream data have been downloaded
				@now_playing = false
				console.log("'#{song_name}': Closing stream.")
				stream.end()
				console.log("'#{song_name}': Closed stream.")
				@play()
			)
			request.on('response', (music) => # Downloading stream data
				console.log("'#{song_name}': Piping to decoder.")
				stream = music.pipe(decoder)
				console.log("'#{song_name}': Piped to decoder.")

				stream.on('format', (format) =>
					console.log("'#{song_name}': Waiting 10s to sync with all devices.")
					setTimeout(=>
						console.log("'#{song_name}': Piping to speaker.")
						stream.pipe(new Speaker(format)) # Playing music
						console.log("'#{song_name}': Piped to speaker.")
					, 10000)
				)
			)
		)

module.exports = Music
