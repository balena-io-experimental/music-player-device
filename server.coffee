Grooveshark = require './grooveshark'
Music = require './music'

Grooveshark.getStream('Paranoid Black Sabbath', (err, url) ->
	Music.play(url)
)
