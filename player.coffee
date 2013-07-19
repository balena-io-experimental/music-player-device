Lame = require('lame')
Speaker = require('speaker')
{EventEmitter2} = require('eventemitter2')

class Player extends EventEmitter2
	constructor: (@song) -> super()
	log: (args...) -> console.log("'#{@song.artist} - #{@song.name}':", args...)
	speaker: null
	decoder: new Lame.Decoder()
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
		)

	play: ->
		@log('Playing')
		@decoder.pipe(@speaker)
		@emit('playing')

	pause: ->
		@log('Pausing')
		@decoder.unpipe(@speaker)
		@emit('paused')

	end: ->
		@log('Stopping')
		@pause()
		@speaker.end()

module.exports = Player
