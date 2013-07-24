Http = require('http')
GS = require('grooveshark-streaming')
Player = require('./player')
async = require('async')
sntp = require('sntp')

class Playlist extends Array
	constructor: -> super()

	playing: null
	log: (args...) ->
		if @playing?
			@playing.log(args...)
		else
			console.log("No Song Playing: ", args...)

	getStream: (song, callback) -> # Searching for song_name on Grooveshark
		@log("Getting info.")
		GS.Tinysong.getSongInfo(song.name, song.artist, (err, info) => # Getting SongID
			if err or !info? # Not found
				@log("Not found.")
				callback(true) # Cannot return err because GS has a bug and returns null
				return
			@log("Got info", info)

			@log("Getting stream_url.")
			GS.Grooveshark.getStreamingUrl(info.SongID, (err, stream_url) =>
				@log("Got stream_url '#{stream_url}.'")
				if err # Could not fetch stream_url
					@log("Error getting stream url.", err)
					callback(err)
					return

				request = Http.get(stream_url) # Getting stream data
				request.on('response', (songStream) -> callback(null, songStream, request))
				request.on('error', callback)
			)
		)

	skip: ->
		@log('Skipping')
		if @playing?
			@playing.end()

	play: ->
		console.log("Music.play(): Checking if playing now or no song in queue.")
		if @playing or @length is 0
			console.log("Music.play(): Playing now or no song in queue.")
			return
		console.log("Music.play(): Can play.")

		song = @shift() # Getting the next song_name
		@playing = new Player(song)
		@playing.on('end', =>
			@playing = null
			@play()
		)
		console.log("Music.play(): Got", song)

		tasks =
			time: sntp.time
			song: (callback) =>
				@getStream(song, (error, songStream, request) =>
					if error
						return callback(error)

					@playing.on('end', =>
						@log('Aborting request')
						request.abort()
					)
					@playing.buffer(songStream)

					interval = setInterval(=>
						time_remaining = song.start_time - Date.now()
						if time_remaining < 0
							@log("Should be playing now.")
							clearInterval(interval)
						else
							@log("Waiting #{time_remaining / 1000}s to sync with all devices.")
					, 1000)
					callback()
				)

		async.parallel(tasks, (error, results) =>
			if error
				@playing = null
				return @play()

			# Use a setTimeout to idle until 500ms before the planned start time.
			setTimeout(=>
				# Busy wait to be as accurate as possible to the start time.
				while song.start_time - Date.now() > 0
					null
				@playing.play() # Playing music
			, (song.start_time - 500) - Date.now() + results.time.t)
		)

module.exports = Playlist
