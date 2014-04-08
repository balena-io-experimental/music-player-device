sntp = require('sntp')
through = require('through')
Throttle = require('throttle')
stream = require('stream')

module.exports.startSntp = (cb) ->
  sntp.start(clockSyncRefresh: 5 * 60 * 1000, cb)

module.exports.currentTime = (cb) ->
  sntp.time (err, time) ->
    if err
      cb(null, Date.now())
      console.error "SNTP Error", err
      return
    cb(null, Date.now() + time.t)

module.exports.currentTimeSync = currentTimeSync = ->
  sntp.now()

module.exports.timeKeeper = (start) ->
  CHANNELS = 2
  BIT_DEPTH = 16
  RATE = 44100
  BYTE_PER_SEC = RATE * BIT_DEPTH / 8 * CHANNELS
  BYTE_PER_MSEC = BYTE_PER_SEC / 1000
  # Maximum accepted deviation from ideal timing
  EPSILON_MS = 20

  # State variables
  #start = null
  actualBytes = 0

  # The actual stream processing function
  return through (chunk) ->
    now = currentTimeSync()
    # Initialise start at the first chunk of data
    start or= now

    # Derive the bytes that should have been processed if there was no time skew
    idealBytes = (now - start) * BYTE_PER_MSEC

    diffBytes = actualBytes - idealBytes

    diffMsec = diffBytes / BYTE_PER_MSEC
    console.log('Time deviation:', diffMsec.toFixed(2) + 'ms')

    # Only correct the stream if we're out of the EPSILON region
    if Math.abs(diffMsec) < EPSILON_MS
      correctedChunk = chunk
    else
      console.log('Epsilon exceeded! correcting')
      #MAX_ALLOWED = 1/20
      #if diffBytes > chunk.length * MAX_ALLOWED
      #    diffBytes = chunk.length * MAX_ALLOWED
      # The buffer size should be a multiple of 4
      diffBytes = diffBytes - (diffBytes % 4)
      correctedChunk = new Buffer(chunk.length + diffBytes)
      correctedChunk.fill(0)
      chunk.copy(correctedChunk)

    @emit('data', correctedChunk)
    #callback()

    actualBytes += chunk.length
