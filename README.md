# Music Player

This project is a [Resin.io][resin]-supercharged project for playing a playlist on Resin-supported devices, *synchronised* to one another.

The project currently uses [Grooveshark][grooveshark] to stream music specified in a separate [frontend application][frontend-code].

We currently host the frontend on GitHub Pages - [frontend][frontend-pages], this is hooked up to a [Firebase][firebase] backend. This will be customisable soon.

The project is in major development at the moment so don't expect stable behaviour just yet :)

## Configuration

To change configuration options you can either edit `config.json` directly before pushing to Resin.io, or preferably use environmental variables via the application screen.

Configuration variables use [camelCase][camel] in the `config.json` for consistency with code but [SNAKE_CASE][snake] in environment variables for consistency with typical environment variable syntax - the code automatically converts between the two.

## Configuration Variables

* Debug Mode - `DEBUG_MODE` (environment variable) - `debugMode` (`config.json` key) - Determines whether debug output will be shown in logs.
* Firebase URL - `FIREBASE_URL` - `firebaseUrl` - The [Firebase][firebase] backend to use.
* Grace Period (ms) - `GRACE` - `grace` - The 'grace period' i.e. delay before starting to play to allow devices to synchronise.
* Maximum Skew (ms) - `MAX_SKEW` - `maxSkew` - The maximum skew between track time and expected time in the track.
* Minimum Skew Correction Period (ms) - `MIN_SKEW_CORRECTION_PERIOD` - `minSkewCorrectionPeriod` - The minimum delay between skew corrections. Skew corrections result in 'dead air' while the playback stream is corrected, allowing this to recur frequently results in unpleasant 'stutter'. This allows this effect to be reduced at the cost of potential skew.
* Setup Grace Period (ms) - `SETUP_GRACE` - `setupGrace` - The grace period before starting to play doesn't take into account the time taken to setup playback - this specifies the time given for initial playback to be setup, preventing the track from *starting* behind schedule.

[resin]:http://resin.io
[grooveshark]:http://grooveshark.com/
[firebase]:https://www.firebase.com/

[frontend-code]:https://github.com/resin-io/music-player-web-front-end
[frontend-pages]:http://resin-io.github.io/music-player-web-front-end/#/

[camel]:http://en.wikipedia.org/wiki/CamelCase
[snake]:http://en.wikipedia.org/wiki/Snake_case
