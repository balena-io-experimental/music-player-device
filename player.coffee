Lame = require('lame')
Speaker = require('speaker')
{EventEmitter2} = require('eventemitter2')

class Player extends EventEmitter2
	constructor: (@song) ->
		super()
		@decoder = new Lame.Decoder()
		@speaker = null
		@ready = false
	log: (args...) -> console.log("'#{@song.artist} - #{@song.name}':", args...)
	buffer: (songStream) ->
		@log("Piping to decoder.")
		songStream.pipe(@decoder)
		@log("Piped to decoder.")

		@decoder.on('format', (format) =>
			@speaker = new Speaker(format)
			@speaker.on('flush', =>
				@log("Song finished.")
				@playing = null
				@log("Closing songStream.")
				songStream?.unpipe(@decoder)
				songStream = null
				@log("Closed songStream.")
				@log("Closing decoder.")
				@decoder?.unpipe(@speaker)
				@decoder = null
				@log("Closed decoder.")
				@emit('end')
			)
			@ready = true
			@emit('ready')
		)

	_play:  ->
		@decoder.pipe(@speaker)
		@emit('playing')

	play: ->
		@log('Playing')
		if @ready
			@_play()
		else
			@once('ready', @_play)

	pause: ->
		@log('Pausing')
		@off('ready', @_play)
		@decoder.unpipe(@speaker)
		@emit('paused')

	end: ->
		@log('Stopping')
		@pause()
		@speaker.end()

module.exports = Player
