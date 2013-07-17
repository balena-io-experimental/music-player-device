http = require 'http'
lame = require 'lame'
speaker = require 'speaker'
decoder = new lame.Decoder()

Music =
	stream: null
	play: (url) ->
		req = http.get(url)
		req.on('response', (res) =>
			@stream = res.pipe(decoder)
			@stream.on('format', (format) ->
				@pipe(new speaker(format))
			)
		)
	stop: ->
		@stream?.end()

module.exports = Music
