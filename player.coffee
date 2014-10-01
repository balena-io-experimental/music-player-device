Lame = require 'lame'
{ EventEmitter2 } = require 'eventemitter2'
Speaker = require 'speaker'

config = require './config'
skewCorrection = require './skew-correction'
{ currentTimeSync } = require './util'

module.exports = class extends EventEmitter2
	constructor: ->
		super

		@decoder = new Lame.Decoder()
		@ready = false
		@speaker = null
		@skewCorrection = null

	setTitle: (@title) ->

	log: (args...) ->
		console.log("'#{@title}':", args...)

	buffer: (songStream) ->
		@log('Piping to decoder.')
		songStream.pipe(@decoder)
		@log('Piped to decoder.')

		@decoder.on 'format', (@format) =>
			@speaker = new Speaker(@format)
			@speaker.on 'flush', =>
				@log('Song finished.')
				@playing = null
				@log('Closing songStream.')
				songStream?.unpipe()
				songStream = null
				@log('Closed songStream.')
				@log('Closing decoder.')
				@decoder?.unpipe()
				@decoder = null
				@log('Closed decoder.')
				@emit('end')
			@ready = true
			@emit('ready')

	_play:	->
		@decoder
			.pipe(@skewCorrection)
			.pipe(@speaker)
		@emit('playing')

	play: (startTime) ->
		@startTime = startTime ? currentTimeSync()
		@skewCorrection = skewCorrection(@startTime, @format)
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
