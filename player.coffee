_ = require 'lodash'
Lame = require 'lame'
{ EventEmitter2 } = require 'eventemitter2'
Speaker = require 'speaker'

config = require './config'
skewCorrection = require './skew-correction'
util = require './util'

{ currentTimeSync, log, logLevel: lvl } = util

module.exports = class extends EventEmitter2
	constructor: ->
		super

		@decoder = new Lame.Decoder()
		@ready = false
		@speaker = null

	setTitle: (title) ->
		@title = util.capitalise(title)

	log: (logLevel, args...) ->
		# Prefix all log messages with song title.
		log(logLevel, @title, args...)

	buffer: (songStream) ->
		@log(lvl.debug, 'Piping to decoder.')
		songStream.pipe(@decoder)
		@log(lvl.debug, 'Piped to decoder.')

		@decoder.on 'format', (@format) =>
			@speaker = new Speaker(@format)
			@speaker.on 'flush', =>
				@log(lvl.release, 'Song finished.')
				@playing = null
				@log(lvl.debug, 'Closing songStream.')
				songStream?.unpipe()
				songStream = null
				@log(lvl.debug, 'Closed songStream.')
				@log(lvl.debug, 'Closing decoder.')
				@decoder?.unpipe()
				@decoder = null
				@log(lvl.debug, 'Closed decoder.')
				@emit('end')
			@ready = true
			@emit('ready')

	_play:	->
		@decoder
			.pipe(skewCorrection(@startTime, @format))
			.pipe(@speaker)
		@emit('playing')

	play: (startTime) ->
		@startTime = startTime ? currentTimeSync()
		@log(lvl.release, 'Playing.')

		if @ready
			@_play()
		else
			@once('ready', @_play)

	pause: ->
		@log(lvl.release, 'Pausing.')

		@off('ready', @_play)
		@decoder?.unpipe()
		@emit('paused')

	end: ->
		@log(lvl.release, 'Stopping.')
		@pause()
		@speaker?.end()
