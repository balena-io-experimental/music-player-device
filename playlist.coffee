# imports
http = require('http')

async = require('async')
Firebase = require('firebase')
{EventEmitter2} = require('eventemitter2')

externalHelper = require('./external-helper')
Player = require('./player')
{currentTime, currentTimeSync} = require('./lib/util')

# constant

{GRACE} = require('./config') # ms

module.exports = class Playlist
	constructor: (fbUrl) ->

		# state
		@_playlistReceived = false
		@_playlist = null
		@_prevNowPlayingState = null
		@_nowPlayingState = null
		@_progressInterval = null
		@_player = null

		# Firebase refs
		fireRef = new Firebase(fbUrl)
		@_playlistRef = fireRef.child('playlist')
		@_nowPlayingRef = fireRef.child('playing')

		# events routing
		@_eventsHub = new EventEmitter2()

		# subscribe to FB changes
		@_playlistRef.on 'value', @_onPlaylistChanged.bind(@)
		@_nowPlayingRef.on 'value', @_onNowPlayingChanged.bind(@)

		# subscribe to events

		@_eventsHub.on 'stop', @onStop.bind(@)
		@_eventsHub.on 'play_next', @onPlayNext.bind(@)
		@_eventsHub.on 'play', @onPlay.bind(@)


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
				console.log 'Something is going, will join the party from the next song'
				return
			console.log 'Looks like nobody is playing, resetting'
			@resetNowPlaying()
		, 5000

	_onStateChanged: ->
		# exit if we didn't get @_nowPlayingState yet
		if not @_nowPlayingState
			return

		# first time we got nowPlayingState schedule reset if needed
		if not @_prevNowPlayingState
			@resetIfNeeded()

		switchToStop = not @_nowPlayingState?.shouldPlay
		if switchToStop
			return @_eventsHub.emit('stop')

		# don't do any playback until we get all data
		if not @_playlistReceived
			return

		switchToStart = @_prevNowPlayingState?.shouldPlay == false and @_nowPlayingState?.shouldPlay
		if switchToStart
			return @_eventsHub.emit('play_next')

		nobodyPlaying = not @_nowPlayingState?.songId and @_nowPlayingState?.shouldPlay
		if nobodyPlaying
			return @_eventsHub.emit('play_next')

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

	# play functions

	trackProgress: ->
		playStart = @_nowPlayingState?.playStart
		if not playStart
			return
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
			if currentVal?.songId != songId
				return
			if not currentVal?.shouldPlay
				return
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

	lookupSong: (songId, cb) ->
		song = @_playlist[songId]
		if song.externalId
			return cb(null, song)
		songRef = @_playlistRef.child(songId)
		origTitle = song.title
		externalHelper.lookupSong origTitle, (err, info) =>
			if err
				console.log "Get info error", err
				@_cleanPlayer()
				songRef.update
					title: "Song not found"
					origTitle: origTitle
					completed: true
					externalId: null
				# broadcast that we should switch to the next song
				@_nowPlayingRef.transaction (currentVal) ->
					if currentVal?.songId != songId
						return
					return shouldPlay: true
				return cb err
			cb(null, info)
			songRef.update
				title: info.title
				origTitle: origTitle
				externalId: info.externalId

	getSongStream: (externalId, cb) ->
		externalHelper.getStreamingUrl externalId, (err, streamUrl) ->
			return cb(err) if err
			request = http.get(streamUrl) # Getting stream data
			request.on 'response', (stream) ->
				cb(null, { stream, request })
			request.on 'error', cb

	onPlay: ->
		console.log 'play'
		if not @_nowPlayingState?.shouldPlay
			console.log('shouldPlay == false')
			return

		if @_player # already playing
			console.log('Already playing')
			return

		songId = @_nowPlayingState.songId
		song = @_playlist?[songId]
		if not song
			console.log('Song not found, id:', songId)
			@resetNowPlaying()
			return

		if song.completed
			console.log('Already completed, skip')
			return

		console.log("Got song to play:", song)
		@_player = new Player()
		@_player.setTitle(song.title)
		@_player.on 'end', =>
			@onSongEnded(songId)

		doPlay = @doPlay.bind(@)
		async.auto
			songData: (cb) =>
				@lookupSong(songId, cb)
			stream: ['songData', (cb, results) =>
				info = results.songData
				@getSongStream(info.externalId, cb)
			]
		, (err, results) =>
			if err
				console.error(err)
				return
			if not @_player
				console.log('Player disappeared?')
				return
			@_player.setTitle(results.songData.title)
			@_player.on 'end', ->
				console.log('Aborting request')
				results.stream.request.abort()
			@_player.buffer(results.stream.stream)
			diff = @_nowPlayingState.playStart - currentTimeSync()
			if diff <= 0
				setImmediate(doPlay)
			else
				setTimeout(doPlay, diff)

	onPlayNext: ->
		console.log('play_next')
		if not @_nowPlayingState?.shouldPlay
			return
		nextSongId = null
		for id, song of @_playlist
			if not song.completed
				nextSongId = id
				break
		if not nextSongId
			return
		now = currentTimeSync()
		###currentTime (err, now) =>
			if err
				console.log(err)
				return###
		playStart = now + GRACE
		@_nowPlayingRef.transaction (currentVal) ->
			if currentVal?.songId
				return
			if not currentVal?.shouldPlay
				return
			return {
				shouldPlay: true
				songId: nextSongId
				playStart: playStart
			}

	onStop: ->
		console.log('stop')
		@_cleanPlayer()
		songId = @_nowPlayingState?.songId
		if songId
			@onSongEnded(songId)
