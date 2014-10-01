stream = require 'grooveshark-streaming'

# Searching for song_name on Grooveshark
module.exports =
	getData: (song, callback) ->
		console.log('Getting info.')
		# Getting SongID
		stream.Tinysong.getSongInfo song, '', (err, info) ->
			if err or not info # Not found
				console.log('Not found.')
				# Cannot return err because Groove shark has a bug and returns null.
				return callback(err or true)
			console.log('Got info', info)
			callback null, {
				artist: info.ArtistName
				title: info.SongName
				id: info.SongID
			}

	getStreamingUrl: (songId, callback) ->
		console.log('Getting streamUrl.')

		stream.Grooveshark.getStreamingUrl songId, (err, streamUrl) ->
			console.log("Got stream URL '#{streamUrl}.'")

			# Could not fetch streamUrl.
			if err
				console.error('Error getting stream url.', err)
				return callback(err)

			callback(null, streamUrl)

	lookupSong: (title, callback) ->
		@getData title, (err, info) ->
			err ?= code: 'not_found' if !info
			return callback(err) if err

			data =
				externalId: info.id
				title: "#{info.artist} - #{info.title}"

			callback(null, data)
