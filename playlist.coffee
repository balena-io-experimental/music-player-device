async = require 'async'
{ EventEmitter2 } = require 'eventemitter2'
http = require 'http'
Firebase = require 'firebase'

config = require './config'
grooveshark = require './grooveshark'
Player = require './player'
{ currentTimeSync, log, logLevel: lvl } = require './util'

module.exports = class Playlist
	constructor: (firebaseUrl) ->

		# State.
		@_playlistReceived = false
		@_playlist = null
		@_prevNowPlayingState = null
		@_nowPlayingState = null
		@_progressInterval = null
		@_player = null

		# Firebase references.
		fireRef = new Firebase(firebaseUrl)
		@_playlistRef = fireRef.child('playlist')
		@_nowPlayingRef = fireRef.child('playing')

		# Event routing.
		@_eventsHub = new EventEmitter2()

		# Subscribe to firebase changes.
		@_playlistRef.on('value', @_onPlaylistChanged.bind(@))
		@_nowPlayingRef.on('value', @_onNowPlayingChanged.bind(@))

		# Subscribe to events.
		@_eventsHub.on('stop', @onStop.bind(@))
		@_eventsHub.on('play_next', @onPlayNext.bind(@))
		@_eventsHub.on('play', @onPlay.bind(@))

	resetNowPlaying: ->
		@_nowPlayingRef.update
			songId: null
			progress: null

	resetIfNeeded: ->
		initialNowPlayingState = @_nowPlayingState

		setTimeout =>
			nowPlayingState = @_nowPlayingState

			songChanged = nowPlayingState.songId != initialNowPlayingState.songId
			progressChanged = nowPlayingState.progress != initialNowPlayingState.progress
			shouldPlayChanged = nowPlayingState.shouldPlay != initialNowPlayingState.shouldPlay

			if songChanged or progressChanged or shouldPlayChanged
				return log(lvl.release, 'Song is playing, will join from the next song.')

			log(lvl.release, 'No other devices playing, resetting.')
			@resetNowPlaying()
		, 5000

	_onStateChanged: ->
		# Exit if we haven't establish @_nowPlayingState yet.
		return if not @_nowPlayingState

		# Reset if needed on the first time we establish @_nowPlayingState.
		@resetIfNeeded() if not @_prevNowPlayingState

		# Should we switch to the stopped state?
		switchToStop = not @_nowPlayingState?.shouldPlay
		return @_eventsHub.emit('stop') if switchToStop

		# Don't do any playback until we get all data.
		return if not @_playlistReceived

		# Should we switch to the started state?
		switchToStart = @_prevNowPlayingState?.shouldPlay is false and @_nowPlayingState?.shouldPlay
		return @_eventsHub.emit('play_next') if switchToStart

		nobodyPlaying = not @_nowPlayingState?.songId and @_nowPlayingState?.shouldPlay
		return @_eventsHub.emit('play_next') if nobodyPlaying

		songEnded = @_prevNowPlayingState?.songId and not @_nowPlayingState?.songId
		if songEnded and @_nowPlayingState?.shouldPlay
			return @_eventsHub.emit('play_next')

		newSong = not @_prevNowPlayingState?.songId and @_nowPlayingState?.songId
		if newSong and @_nowPlayingState?.shouldPlay
			return @_eventsHub.emit('play')

	_onPlaylistChanged: (snapshot) ->
		@_playlistReceived = true
		@_playlist = snapshot.val()
		@_onStateChanged()

	_onNowPlayingChanged: (snapshot) ->
		@_prevNowPlayingState = @_nowPlayingState
		@_nowPlayingState = snapshot.val()
		@_onStateChanged()

	# Playback methods.

	trackProgress: ->
		playStart = @_nowPlayingState?.playStart
		return if not playStart

		now = currentTimeSync()
		progress = Math.floor((now - playStart) / 1000)
		@_nowPlayingRef.child('progress').set(progress)

	_cleanPlayer: ->
		@_player?.end()
		@_player = null

	onSongEnded: (songId) ->
		clearInterval(@_progressInterval)
		songRef = @_playlistRef.child(songId)
		songRef.child('completed').set(true)
		@_cleanPlayer()
		@_nowPlayingRef.transaction (currentVal) ->
			return if currentVal?.songId != songId or not currentVal?.shouldPlay

			return {
				songId: null
				shouldPlay: true
				playStart: null
			}

	doPlay: ->
		@_player.play(@_nowPlayingState.playStart)
		@_progressInterval = setInterval =>
			@trackProgress()
		, 500

	lookupSong: (songId, callback) ->
		song = @_playlist[songId]

		# Return if we've already obtained a stream URL.
		return callback(null, song) if song.externalId

		songRef = @_playlistRef.child(songId)
		origTitle = song.title
		grooveshark.lookupSong origTitle, (err, info) =>
			if err
				log(lvl.error, err)
				@_cleanPlayer()
				songRef.update
					title: 'Song not found'
					origTitle: origTitle
					completed: true
					externalId: null

				# Broadcast that we should switch to the next song.
				@_nowPlayingRef.transaction (currentVal) ->
					return if currentVal?.songId != songId

					return shouldPlay: true

				return callback(err)

			callback(null, info)
			songRef.update
				title: info.title
				origTitle: origTitle
				externalId: info.externalId

	getSongStream: (externalId, callback) ->
		grooveshark.getStreamingUrl externalId, (err, streamUrl) ->
			return callback(err) if err

			request = http.get(streamUrl)
			request.on 'response', (stream) ->
				callback(null, { stream, request })
			request.on('error', callback)

	onPlay: ->
		log(lvl.release, 'Play.')

		if not @_nowPlayingState?.shouldPlay
			return log lvl.error,
				"Attempting to play a track marked as shouldn't play."

		return log(lvl.error, 'Already playing.') if @_player

		songId = @_nowPlayingState.songId
		song = @_playlist?[songId]
		if not song
			@resetNowPlaying()
			return log(lvl.release, 'Song not found, id:', songId)

		return log(lvl.release, 'Already completed, skipping.') if song.completed

		log(lvl.release, "Playing '#{song?.title}'")
		@_player = new Player()
		@_player.setTitle(song.title)
		@_player.on 'end', =>
			@onSongEnded(songId)

		doPlay = @doPlay.bind(@)
		async.auto
			songData: (callback) =>
				@lookupSong(songId, callback)
			stream: ['songData', (callback, results) =>
				info = results.songData
				@getSongStream(info.externalId, callback)
			]
		, (err, results) =>
			return log(lvl.error, err) if err
			return log(lvl.error, 'Player object not found?!') if not @_player

			log(lvl.debug, "Returned song title: #{results.songData.title} ")

			@_player.on 'end', ->
				log(lvl.release, 'Aborting request.')
				results.stream.request.abort()
			@_player.buffer(results.stream.stream)
			diff = @_nowPlayingState.playStart - currentTimeSync()
			if diff <= 0
				setImmediate(doPlay)
			else
				setTimeout(doPlay, diff)

	onPlayNext: ->
		log(lvl.release, 'Play Next.')

		return if not @_nowPlayingState?.shouldPlay

		nextSongId = null
		for id, song of @_playlist
			if not song.completed
				nextSongId = id
				break

		return if not nextSongId

		now = currentTimeSync()
		playStart = now + config.grace #ms

		@_nowPlayingRef.transaction (currentVal) ->
			return if currentVal?.songId or not currentVal?.shouldPlay

			return {
				shouldPlay: true
				songId: nextSongId
				playStart: playStart
			}

	onStop: ->
		log(lvl.release, 'Stop.')

		@_cleanPlayer()

		songId = @_nowPlayingState?.songId
		@onSongEnded(songId) if songId
