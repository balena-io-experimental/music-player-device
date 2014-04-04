# imports
http = require('http')

sntp = require('sntp')
async = require('async')
Firebase = require('firebase')
{EventEmitter2} = require('eventemitter2')

externalHelper = require('./external-helper')
Player = require('./player')

# constant

{GRACE} = require('./config') # ms

module.exports = class Playlist
  constructor: (fbUrl) ->

    # state
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

  currentTime: (cb) ->
    sntp.time (err, time) ->
      if err
        cb(null, Date.now())
        console.error "SNTP Error", err
        return
      cb(null, Date.now() + time.t)


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

    # don't do anything until we get all data
    # TODO: check how empty list is returned
    if not @_playlist
      return

    switchToStop = not @_nowPlayingState?.shouldPlay
    if switchToStop
      return @_eventsHub.emit('stop')

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
    now = sntp.now()
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
    @_player.play()
    @_progressInterval = setInterval(
      @trackProgress.bind(@),
    500)

  lookupSong: (songId, cb) ->
    song = @_playlist[songId]
    if song.externalId
      return cb(null, externalId: song.externalId)
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

    currentTime = @currentTime.bind(@)
    doPlay = @doPlay.bind(@)
    async.auto
      songData: (cb) =>
        @lookupSong(songId, cb)
      stream: ['songData', (cb, results) =>
        info = results.songData
        @getSongStream(info.externalId, cb)
      ],
      now: ['stream', currentTime]
    , (err, results) =>
      if err
        console.error(err)
        return
      if not @_player
        console.log('Player disappeared?')
        return
      diff = @_nowPlayingState.playStart - results.now
      if diff <= 0
        @_cleanPlayer()
        console.log('Now                ', new Date(results.now))
        console.log('Should have started', new Date(@_nowPlayingState.playStart))
        console.log('Diff', diff)
        console.log('Too little too late')
        @resetIfNeeded()
        return
      setTimeout(doPlay, diff)
      @_player.setTitle(results.songData.title or @_playlist[songId].title)
      @_player.on 'end', ->
        console.log('Aborting request')
        results.stream.request.abort()
      @_player.buffer(results.stream.stream)

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
    @currentTime (err, now) =>
      if err
        console.log(err)
        return
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
