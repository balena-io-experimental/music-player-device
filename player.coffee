Lame = require('lame')
Speaker = require('speaker')
{EventEmitter2} = require('eventemitter2')

{currentTimeSync, skipStart, throttle} = require('./lib/util')

class Player extends EventEmitter2
  constructor: ->
    super()
    @decoder = new Lame.Decoder()
    @speaker = null
    @timeKeeper = null
    @ready = false

  setTitle: (@title) ->

  log: (args...) ->
    console.log("'#{@title}':", args...)

  buffer: (songStream) ->
    @log("Piping to decoder.")
    songStream.pipe(@decoder)
    @log("Piped to decoder.")

    @decoder.on 'format', (format) =>
      @speaker = new Speaker(format)
      @speaker.on 'flush', =>
        @log("Song finished.")
        @playing = null
        @log("Closing songStream.")
        songStream?.unpipe()
        songStream = null
        @log("Closed songStream.")
        @log("Closing decoder.")
        @decoder?.unpipe()
        @decoder = null
        @log("Closed decoder.")
        @emit('end')
      @ready = true
      @emit('ready')

  _play:  ->
    @decoder
      .pipe(@skipStart)
      .pipe(@throttle)
      .pipe(@speaker)
    @emit('playing')

  play: (startTime) ->
    if startTime
      @startTime = startTime
    if not @startTime
      @startTime = currentTimeSync()
    @skipStart = skipStart(@startTime)
    @throttle = throttle()
    @log('Playing')
    if @ready
      @_play()
    else
      @once('ready', @_play)

  pause: ->
    @log('Pausing')
    @off('ready', @_play)
    @decoder?.unpipe()
    @emit('paused')

  end: ->
    @log('Stopping')
    @pause()
    @speaker?.end()

module.exports = Player
