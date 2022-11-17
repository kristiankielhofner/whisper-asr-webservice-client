# whisper-asr-webservice-client

Linux and Mac OS X client for https://github.com/ahmetoner/whisper-asr-webservice

Run `./asr.sh asr`. On Mac and Linux it will try to use the first microphone in the system or default input source (Pulse) but if that doesn't work you can run `./asr.sh list`. In the list of audio input devices just pass the device number or Pulse source to `asr.sh`:

Mac:
`./asr.sh asr 2`

Linux:
`./asr.sh asr alsa_output.usb-Generic_USB_Audio-00.analog-stereo.monitor`

(or whatever)

If that doesn't work or you want to pass files provide the relative or full path of a file:

`./asr.sh asr russian.flac`

There are some system software dependencies it uses and will check for:

- jq
- curl
- file

Recording from microphone is above + ffmpeg. All are available on a recent Linux distro. On Mac use brew.

Some benchmarks for various file formats and recording length are available in benchmarks.txt. On my RTX 3090 short files (<30 sec) do ASR 5x faster than realtime. For longer files like the 60 minute sample for the benchmarks it's usually closer to 20x faster than realtime. Of course this also depends on your bandwidth, format, server hardware, etc.
