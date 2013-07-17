GS = require 'grooveshark-streaming'

Grooveshark =
	getStream: (query, callback) ->
		GS.Tinysong.getSongInfo(query, '', (err, info) ->
			GS.Grooveshark.getStreamingUrl(info.SongID, (err, url) ->
				callback(err, url)
			)
		)

module.exports = Grooveshark
