DEBUG = true
if !DEBUG
	console.log = ->

Music = require('./music')
Twitter = require('ntwitter')

# Twitter requires OAuth even for read-only requests
twit = new Twitter(
	consumer_key: 'n4kPMCD2xt7tNSWA448ag'
	consumer_secret: '50J23gp5X9NSXRMx2SvU4Sq0JQJowi18sqxNCOEBZE'
	access_token_key: '1600669826-zlypolcdXrEVVgI9GcKkVC4qfE7n8zQZvMV7UrL'
	access_token_secret: '2u21AcQl0DeSPGjV0l2UukwHz4pT3wdhPlZhMCO9o'
)

# Getting the user timeline
twit.stream('user', {}, (timeline) ->
	timeline.on('data', (tweet) ->
		return if tweet.text is undefined # Not a tweet

		console.log("New tweet: #{tweet.text}")
		# tweet.text syntax shoud be: #music-player song_name artist_name
		if /music-player/.test(tweet.text)
			tweet_parts = tweet.text.split(' ') # Splitting the tweet
			tweet_parts.shift() # Removing #music-player
			song_name = tweet_parts.join(' ') # Joining song_name and artist_name
			# Currently song_name and artist_name is the same thing

			console.log("'#{song_name}': Adding to queue.")
			Music.queue.push(song_name) # Pushing the name and when to start playing
			console.log("'#{song_name}': Added to queue.")
			Music.play() # Start playing the queue or do nothing if already playing
	)
)
