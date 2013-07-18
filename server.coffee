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
watchTwitter = ->
	twitter.stream('user', {}, (timeline) ->
		timeline.on('data', (tweet) ->
			return if tweet.text is undefined # Not a tweet

			console.log("'#{tweet.text}': Got tweet.")
			# tweet.text syntax shoud be: #music-player song_name artist_name
			if /music-player/.test(tweet.text)
				tweet_parts = tweet.text.replace(/^.*music-player\s*/, '') # Removing #music-player
				tweet_parts = tweet_parts.split(' - ')

				switch tweet_parts.length
					when 1
						[song_name] = tweet_parts
					else
						[artist_name, song_name] = tweet_parts

				tweet_time = new Date(tweet.created_at).getTime() # UNIX Timestamp
				console.log("'#{tweet.text}': Created at '#{tweet_time}'.")
				delay = 10000 # ms
				song =
					name: song_name
					artist: artist_name ? ''
					start_time: tweet_time + delay # Playing delayed te allow all devices to sync
				console.log(song)

				console.log("'#{song.artist} - #{song.name}': Adding to queue.")
				Music.queue.push(song) # Pushing the name and when to start playing
				console.log("'#{song.artist} - #{song.name}': Added to queue.")
				Music.play() # Start playing the queue or do nothing if already playing
		)

		rewatched = false
		rewatch = (args...) ->
			console.log('Trying to rewatch:', rewatched, args)
			if rewatched
				return
			rewatched = true
			watchTwitter()
		# Handle a disconnection
		timeline.on('end', rewatch)
		# Handle a 'silent' disconnection from Twitter, no end/error event fired
		timeline.on('destroy', rewatch)
		# Handle an error
		timeline.on('error', rewatch)
	)
watchTwitter()