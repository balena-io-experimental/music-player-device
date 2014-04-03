GS = require './lib/grooveshark'

module.exports.lookupSong = (title, cb) ->
  # return object { externalId, title }
  GS.getData title, (err, info) ->
    if not err and not info
      err = code: 'not_found'
    if err
      return cb err
    cb null,
      externalId: info.id
      title: "#{info.artist} - #{info.title}"

module.exports.getStreamingUrl = (externalId, cb) ->
  GS.getStreamingUrl externalId, cb
