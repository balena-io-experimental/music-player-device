sntp = require('sntp')
through = require('through')
Throttle = require('throttle')

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


CHANNELS = 2
BIT_DEPTH = 16
FRAME_SIZE = BIT_DEPTH / 8 * CHANNELS
RATE = 44100
BYTE_PER_SEC = RATE * FRAME_SIZE
BYTE_PER_MSEC = RATE / 1000
# Maximum accepted deviation from ideal timing
EPSILON_MS = 20
EPSILON_BYTES = EPSILON_MS * BYTE_PER_MSEC

module.exports.throttle = ->
  new Throttle(BYTE_PER_SEC)

module.exports.skipStart = (start) ->
  # State variables
  actualBytes = 0

  # The actual stream processing function
  return through (chunk) ->
    now = currentTimeSync()
    # Initialise start at the first chunk of data
    start or= now

    chunkLength = chunk.length
    # Derive the bytes that should have been processed if there was no time skew
    idealBytes = (now - start) * BYTE_PER_MSEC

    diffBytes = actualBytes - idealBytes
    #diffMsec = diffBytes / BYTE_PER_MSEC
    #console.log('Time deviation:', diffMsec.toFixed(2) + 'ms')

    # Only correct the stream if we're too slow (skip song beginning if we are late)
    if diffBytes < -EPSILON_BYTES
      console.log('Epsilon exceeded! correcting')
      # The buffer size should be a multiple of FRAME_SIZE
      diffBytes *= -1
      diffBytes -= diffBytes % FRAME_SIZE
      chunk = chunk.slice(diffBytes)

    @queue(chunk)
    actualBytes += chunkLength
