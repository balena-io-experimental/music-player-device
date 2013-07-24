settings = require('./settings.json')
sntp = require('sntp')

if !settings.DEBUG
	console.log = ->

# SERVER_TIME_DIFF = 0

Playlist = require('./playlist')
Twitter = require('ntwitter')
request = require('request')

# Twitter requires OAuth even for read-only requests
twitter = new Twitter(
	settings.TWITTER
)

playlist = new Playlist()

commands =
	play: (tweet_text, tweet_time) ->
	
		tweet_parts = tweet_text.split(' - ')

		tweet_parts = tweet_parts.map((s) -> s.trim())

		switch tweet_parts.length
			when 1
				[song_name] = tweet_parts
			else
				[artist_name, song_name] = tweet_parts

		console.log("'#{tweet_text}': Created at '#{tweet_time}'.")
		song =
			name: song_name
			artist: artist_name ? ''
			start_time: tweet_time + settings.PLAY_DELAY # + SERVER_TIME_DIFF # Playing delayed te allow all devices to sync
		console.log(song)

		console.log("'#{song.artist} - #{song.name}': Adding to queue.")
		playlist.push(song) # Pushing the name and when to start playing
		console.log("'#{song.artist} - #{song.name}': Added to queue.")
		playlist.play() # Start playing the queue or do nothing if already playing

	skip: (text, time) ->
		start = Date.now()
		console.log(Date.now() - start, "Got skip, syncing time", text, time)
		sntp.time((error, result) ->
			now = Date.now() + result.t
			if error
				return console.error(Date.now() - start, "Error synching time", error)
			console.log(Date.now() - start, "Time synched, got offset", result.t)
			console.log(Date.now() - start, "Scheduling skip in", time + 10000 - now)
			setTimeout(->
				console.log(Date.now() - start, "Skipping..")
				playlist.skip()
			, time + 3000 - now)
		)

# Getting the user timeline
watchTwitter = ->
	twitter.stream('user', {}, (timeline) ->
		timeline.on('data', (tweet) ->
			return if tweet.text is undefined # Not a tweet

			console.log("'#{tweet.text}': Got tweet.")
			# tweet.text syntax shoud be: #music-player song_name artist_name
			if /music-player/.test(tweet.text)
				tweet_text = tweet.text.replace(/^.*music-player-?/, '').trim() # Removing #music-player
				tweet_parts = tweet_text.split(' ')
				command = tweet_parts.shift().toLowerCase()
				tweet_text = tweet_parts.join(' ')

				if commands.hasOwnProperty(command)
					commands[command](tweet_text, new Date(tweet.created_at).getTime())
				else
					console.error("Unknown command: #{command}")
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

###
differences = []
syncTime = ->
	startTime = Date.now()
	request 'http://paras.rulemotion.com:2193/time', (err, res, body) ->
		endTime = Date.now()
		delay = endTime - startTime
		ourTime = endTime - (delay / 2) #/
		theirTime = parseInt(body, 10)

		diff = ourTime - theirTime
		differences.push(diff)
		if differences.length >= settings.SERVER_TIME_CHECKS
			avg = differences.reduce(
				(sum, diff) ->
					sum += diff
				0
			) / differences.length #/

			# TODO: Filter outliers
			# differences = differences.filter (diff) ->

		if differences.length >= settings.SERVER_TIME_CHECKS
			console.log('Average delay: ', avg)
			SERVER_TIME_DIFF = avg
			watchTwitter()
		else
			syncTime()
syncTime()
###

watchTwitter()
