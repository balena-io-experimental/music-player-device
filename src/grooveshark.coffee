config = require './config'
stream = require 'grooveshark-streaming'
{ log, logLevel: lvl } = require './util'

# Searching for song_name on Grooveshark
module.exports =
	getData: (song, callback) ->
		[title, artist] = song.split(' - ')
		stream.Tinysong.getSongInfo title, artist, (err, info) ->
			if err or not info
				log(lvl.error, 'Stream for', song, 'not found.')
				# Sometimes Grooveshark erroneously reports no error but also no
				# data.
				return callback(err or true)
			callback null, {
				artist: info.ArtistName
				title: info.SongName
				id: info.SongID
			}

	getStreamingUrl: (songId, callback) ->
		log(lvl.debug, 'Getting stream URL.')

		stream.Grooveshark.getStreamingUrl songId, (err, streamUrl) ->
			log(lvl.debug, "Got stream URL '#{streamUrl}.'")

			# Could not fetch streamUrl.
			if err
				log(lvl.error, err)
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
