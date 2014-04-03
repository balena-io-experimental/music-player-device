# imports
sntp = require 'sntp'
async = require 'async'
Firebase = require 'firebase'
{EventEmitter2} = require 'eventemitter2'

GS = require './grooveshark'
Player = require './player'

# constants and global vars

GRACE = 10000 # ms

playlist = null
prevNowPlayingState = null
nowPlayingState = null
progressInterval = null
player = null

currentTime = (cb) ->
  sntp.time (err, time) ->
    return cb(err) if err
    cb null, Date.now() + time.t

# FB refs

fireRef = new Firebase('https://vocalist.firebaseio.com')
playlistRef = fireRef.child 'playlist'
nowPlayingRef = fireRef.child 'playing'

# events routing

eventsHub = new EventEmitter2()

resetNowPlaying = ->
  # TODO: only erase songId and progress
  nowPlayingRef.set shouldPlay: true

resetIfNeeded = ->
  initialNowPlayingState = nowPlayingState
  if not initialNowPlayingState.shouldPlay
    return
  setTimeout ->
    songChanged = nowPlayingState.songId != initialNowPlayingState.songId
    progressChanged = nowPlayingState.progress != initialNowPlayingState.progress
    if songChanged or progressChanged or not nowPlayingState.shouldPlay
      return
    console.log 'Looks like nobody is playing'
    resetNowPlaying()
  , 5000

onStateChanged = ->
  # first time we got nowPlayingState setup reset if needed
  if nowPlayingState and not prevNowPlayingState
    resetIfNeeded()

  # don't do anything until we get all data
  if not nowPlayingState and playlist
    return

  switchToStop = not nowPlayingState?.shouldPlay
  if switchToStop
    return eventsHub.emit 'stop'

  switchToStart = prevNowPlayingState?.shouldPlay == false and nowPlayingState?.shouldPlay
  if switchToStart
    return eventsHub.emit 'play_next'

  nobodyPlaying = not nowPlayingState?.songId and nowPlayingState?.shouldPlay
  if nobodyPlaying
    return eventsHub.emit 'play_next'

  songEnded = prevNowPlayingState?.songId and not nowPlayingState?.songId
  if songEnded and nowPlayingState?.shouldPlay
    return eventsHub.emit 'play_next'

  newSong = not prevNowPlayingState?.songId and nowPlayingState?.songId
  if newSong and nowPlayingState?.shouldPlay
    return eventsHub.emit 'play'

# subscribe to FB changes

onPlaylistChanged = (snapshot) ->
  playlist = snapshot.val()
  onStateChanged()

onNowPlayingChanged = (snapshot) ->
  prevNowPlayingState = nowPlayingState
  nowPlayingState = snapshot.val()
  onStateChanged()

playlistRef.on 'value', onPlaylistChanged
nowPlayingRef.on 'value', onNowPlayingChanged

# play functions

trackProgress = ->
  if not nowPlayingState?.playStart
    return
  now = sntp.now()
  progress = Math.floor (now - nowPlayingState.playStart) / 1000
  nowPlayingRef.child('progress').set progress

onSongEnded = (songId) ->
  clearInterval progressInterval
  songRef = playlistRef.child(songId)
  songRef.child('completed').set true
  player?.end()
  player = null
  nowPlayingRef.transaction (currentVal) ->
    if currentVal?.songId != songId
      return
    if not currentVal?.shouldPlay
      return
    return {
      songId: null
      shouldPlay: true
      playStart: null
    }

doPlay = ->
  player.play()
  progressInterval = setInterval trackProgress, 990

play = ->
  console.log 'play'
  if not nowPlayingState?.shouldPlay
    console.log 'shouldPlay == false'
    return

  songId = nowPlayingState.songId
  song = playlist?[songId]
  if not song
    console.log 'Song not found, id:', songId
    resetNowPlaying()
    return

  if song.completed
    console.log 'Already completed, skip'
    return

  if player # already playing
    console.log 'Already playing'
    return

  console.log("Music.play(): Got", song)
  player = new Player(song)
  player.on 'end', ->
    onSongEnded songId

  async.auto
    songData: (cb) ->
      if song.gsId
        return cb null, id: song.gsId
      songRef = playlistRef.child(songId)
      origTitle = playlist[songId].title
      GS.getData origTitle, (err, info) ->
        if err
          console.log "Get info error", err
          player = null
          songRef.update
            detectedTitle: "Song not found"
            origTitle: origTitle
            title: null
            completed: true
          nowPlayingRef.transaction (currentVal) ->
            if currentVal?.songId != songId
              return
            return shouldPlay: true
          return cb err
        cb null, info
        songRef.update
          detectedTitle: "#{info.artist} - #{info.title}"
          origTitle: origTitle
          title: null
          gsId: info.id
    stream: ['songData', (cb, results) ->
      info = results.songData
      GS.getStream info.id, (error, stream, request) ->
        cb error, { stream, request }
    ],
    now: ['stream', currentTime]
  , (err, results) ->
    if err
      console.error err
      return
    if not player
      console.log 'Player disappeared?'
      return
    diff = nowPlayingState.playStart - results.now
    if diff <= 0
      player = null
      console.log 'Now                ', new Date(results.now)
      console.log 'Should have started', new Date(nowPlayingState.playStart)
      console.log 'Diff', diff
      console.log 'Too little too late'
      resetIfNeeded()
      return
    setTimeout doPlay, diff
    player.on 'end', ->
      console.log 'Aborting request'
      results.stream.request.abort()
    player.buffer results.stream.stream
    player.setTitle song

playNext = ->
  console.log 'play_next'
  if not nowPlayingState?.shouldPlay
    return
  nextSongId = null
  for id, song of playlist
    if not song.completed
      nextSongId = id
      break
  if not nextSongId
    return
  currentTime (err, now) ->
    if err
      console.log err
      return
    playStart = now + GRACE
    nowPlayingRef.transaction (currentVal) ->
      if currentVal?.songId
        return
      if not currentVal?.shouldPlay
        return
      return {
        shouldPlay: true
        songId: nextSongId
        playStart: playStart
      }

stop = ->
  console.log 'Stop playing'
  player?.end()
  player = null
  songId = nowPlayingState?.songId
  if songId
    onSongEnded songId


# subscribe to events

eventsHub.on 'stop', stop
eventsHub.on 'play_next', playNext
eventsHub.on 'play', play

# run

console.log '\n\n\nRunning'
