DEBUG = true
if !DEBUG
	console.log = ->

Music = require('./music')
Twitter = require('ntwitter')

# Twitter requires OAuth even for read-only requests
twitter = new Twitter(
	consumer_key: 'n4kPMCD2xt7tNSWA448ag'
	consumer_secret: '50J23gp5X9NSXRMx2SvU4Sq0JQJowi18sqxNCOEBZE'
	access_token_key: '1600669826-zlypolcdXrEVVgI9GcKkVC4qfE7n8zQZvMV7UrL'
	access_token_secret: '2u21AcQl0DeSPGjV0l2UukwHz4pT3wdhPlZhMCO9o'
)

# Getting the user timeline
twitter.stream('user', {}, (timeline) ->
	timeline.on('data', (tweet) ->
		return if tweet.text is undefined # Not a tweet

		console.log("'#{tweet.text}': Got tweet.")
		# tweet.text syntax shoud be: #music-player song_name artist_name
		if /music-player/.test(tweet.text)
			tweet_parts = tweet.text.split(' ') # Splitting the tweet
			tweet_parts.shift() # Removing #music-player
			tweet_parts = tweet_parts.join(' ').split(' - ')

			switch tweet_parts.length
				when 1
					[song_name] = tweet_parts
				else
					[artist_name, song_name] = tweet_parts

			tweet_time = new Date(tweet.created_at).getTime() / 1000 # UNIX Timestamp
			console.log("'#{tweet.text}': Created at '#{tweet_time}'.")
			delay = 20 # Seconds
			song =
				name: song_name
				artist: artist_name ? ''
				start_time: (tweet_time + delay) * 1000 # Playing delayed to allow all devices to sync
			console.log(song)

			console.log("'#{song.name}': Adding to queue.")
			Music.queue.push(song) # Pushing the name and when to start playing
			console.log("'#{song.name}': Added to queue.")
			Music.play() # Start playing the queue or do nothing if already playing
	)
)
