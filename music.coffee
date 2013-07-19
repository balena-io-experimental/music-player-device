Http = require('http')
Lame = require('lame')
Speaker = require('speaker')
GS = require('grooveshark-streaming')

Music =
	queue: []
	now_playing: false
	speaker: null
	log: (args...) ->
		prefix =
			if @now_playing
				"'#{@now_playing.artist} - #{@now_playing.name}':"
			else
				"No Song Playing: "
		console.log(prefix, args...)

	getStream: (song, callback) -> # Searching for song_name on Grooveshark
		@log("Getting info.")
		GS.Tinysong.getSongInfo(song.name, song.artist, (err, info) => # Getting SongID
			if info is null # Not found
				@log("Not found.")
				callback(true, null)
				return
			@log("Got info", info)

			@log("Getting stream_url.")
			GS.Grooveshark.getStreamingUrl(info.SongID, (err, stream_url) =>
				@log("Got stream_url '#{stream_url}.'")
				callback(err, stream_url)
			)
		)

	skip: ->
		@log('Skipping')
		if @speaker
			@speaker.close()

	play: ->
		console.log("Music.play(): Checking if playing now or no song in queue.")
		if @now_playing or @queue.length is 0
			console.log("Music.play(): Playing now or no song in queue.")
			return
		console.log("Music.play(): Can play.")

		@now_playing = song = @queue.shift() # Getting the next song_name
		console.log("Music.play(): Got", song)

		@getStream(song, (err, stream_url) =>
			if err # Could not fetch stream_url
				@log("Setting now_playing false.")
				@now_playing = false
				@log("Set now_playing false.")
				return

			request = Http.get(stream_url) # Getting stream data
			decoder = new Lame.Decoder()
			stream = null

			request.on('response', (stream_data) => # Downloading stream data
				@log("Piping to decoder.")
				stream = stream_data.pipe(decoder)
				@log("Piped to decoder.")

				stream.on('format', (format) =>
					interval = setInterval(=>
						time_remaining = song.start_time - Date.now()
						if time_remaining < 0
							@log("Should be playing now.")
							clearInterval(interval)
						else
							@log("Waiting #{time_remaining / 1000}s to sync with all devices.")
					, 1000)

					# Use a setTimeout to idle until 500ms before the planned start time.
					setTimeout(=>
						# Busy wait to be as accurate as possible to the start time.
						while song.start_time - Date.now() > 0
							null
						@log("Piping to speaker.")
						@speaker = new Speaker(format)
						stream.pipe(@speaker) # Playing music
						@log("Piped to speaker.")

						@speaker.on('close', =>
							@log("Song finished.")
							@now_playing = false
							@log("Closing stream.")
							stream.end()
							@log("Closed stream.")
							@play()
						)
					, (song.start_time - 500) - Date.now())
				)
			)
		)

module.exports = Music
