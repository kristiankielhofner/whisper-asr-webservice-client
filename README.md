# whisper-asr-webservice-client

A hackly slapdash thrown together-late-at-night Linux and Mac OS X client for https://github.com/ahmetoner/whisper-asr-webservice

## Get Started & Configuration
You will need to create a `.config` file in this directory with the following:

`BASE_URL="https://your.whisper.api.endpoint.url"`

`USER="username4httpBasicAuth"`

`PASS="password4httpBasicAuth"`

For recording audio if you want to use a file format other than FLAC you can define `RECORD_FORMAT` with the file extension of the format you want. FFmpeg handles the rest!

### Server Magic
In my server side whisper-ast-webservice configuration I enable HTTPS and HTTP Basic Auth by proxying through [Traefik](https://traefik.io/)

### Usage
Run `./asr.sh asr`. On Mac and Linux it will try to use the first microphone in the system (Mac) or default input source (Pulse) but if that doesn't work you can run `./asr.sh list`. In the list of audio input devices just pass the device number or Pulse source to `asr.sh`:

Mac:
`./asr.sh asr 2`

Linux:
`./asr.sh asr alsa_output.usb-Generic_USB_Audio-00.analog-stereo.monitor`

(or whatever)

If that doesn't work or you want to pass files provide the relative or full path of a file:

`./asr.sh asr russian.flac`

### Notes
If Whisper comes back with a language other than en|English it will resubmit the submitted audio for translation to en|English and display both results. 

Currently transcripts are made slightly easier to read with a hacky implementation to replace periods in results with newlines.

### Dependencies
There are some system software dependencies it uses and will check for:

- `jq` (parsing JSON)
- `curl` (POST to service)
- `file` (determine MIME type of submitted audio)

Recording from microphone is above + `ffmpeg`. All are available on a recent Linux distro. On Mac use brew.

Some benchmarks for various file formats and recording length are available in benchmarks.txt. On my RTX 3090 short files (<30 sec) do ASR 5x faster than realtime. For longer files like the 60 minute sample for the benchmarks it's roughly 20x faster than realtime. Of course this also depends on your bandwidth, format, hardware, etc. Translation takes a lot longer.

### TODO
- Clean things up
- Possibly move to Python to use something like https://github.com/wiseman/py-webrtcvad for a hacky "realtime" implementation
- Browser implementation with HTML5 + JS
