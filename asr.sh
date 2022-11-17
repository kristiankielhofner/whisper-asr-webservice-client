#!/bin/bash

# Whisper ASR client
# TODO: Investigate HTTP2 failures and stalls on mac
# TODO: CLEAN UP

# Define output files
AUDIO="asr.flac"
RESULTS="asr.json"
TEXT="asr.txt"

# If we detect languages other than english automatically translate and save here
TRANSLATED_TEXT="asr-translated.txt"

# We need to know where to go
BASE_URL="***REMOVED***"

# HTTP basic auth params
USER="***REMOVED***"
PASS="***REMOVED***"

# FLAC compression level for live capture
FLAC_COMPRESS="12"

# Shell colors
NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
WHITE='\033[1;37m'

check_path() {
  [[ $(type -P "$1") ]] || { echo -e "${RED}Error - you need to install $1${NOCOLOR}" 1>&2; exit 1; }
}

if [ "$OSTYPE" = "linux-gnu" ]; then
  ASR_PLATFORM="linux"
else
  ASR_PLATFORM="mac"
#  AUDIO="asr.wav"
fi

# Cleanup
do_clean() {
  rm -rf "$AUDIO" "$RESULTS" "$TEXT" "$TRANSLATED_TEXT"
}

do_asr() {
  if [ ! -r "$SOURCE" ]; then
    check_path ffmpeg
    do_clean
    echo -e "${YELLOW}Recording audio with ffmpeg - CTRL+C when you want to stop capturing and submit ${RED}BUT WAIT FOR FFMPEG OUTPUT${NOCOLOR}"
    if [ "$ASR_PLATFORM" = "linux" ]; then
      ffmpeg -hide_banner -f pulse -i "$SOURCE" -compression_level "$FLAC_COMPRESS" -ar 16000 -ac 1 "$AUDIO"
    else
      ffmpeg -hide_banner -f avfoundation -i ":$SOURCE" -compression_level "$FLAC_COMPRESS" -ar 16000 -ac 1 "$AUDIO"
    fi
  else
    echo -e "${YELLOW}Using provided file $SOURCE as input${NOCOLOR}"
    export AUDIO="$SOURCE"
  fi

  if [ -f "$AUDIO" ]; then
    MIME=$(file --mime-type -b "$AUDIO")
    echo -e "${YELLOW}Submitting to $BASE_URL - please hold but ASR time is roughly 20x real-time${NOCOLOR}"
    curl --http1.1 -X 'POST' \
    "$BASE_URL/asr?task=transcribe&output=json" \
    -u "$USER:$PASS" \
    -H 'accept: application/json' \
    -H 'Content-Type: multipart/form-data' \
    -F "audio_file=@$AUDIO;type=$MIME" > "$RESULTS"

    LANG=$(cat "$RESULTS" | jq -r .language)
    echo -e "\n${YELLOW}Here is your $LANG language text from Whisper ASR!"
    echo -e "${GREEN}"
    # Unnecessary use of cat award
    cat "$RESULTS" | jq -r .text | tr . '\n' | sed 's/ //' | tee "$TEXT"

    echo -e "\n${YELLOW}Your raw text output can be found in $TEXT"

    if [ "$LANG" != "en" ]; then
      echo -e "\n${YELLOW}Detected non-English language $LANG - translating${NOCOLOR}"
      echo
      whisperTranslate "$AUDIO" "$MIME" "en" | jq -r .text | tr . '\n' | sed 's/ //' > "$TRANSLATED_TEXT"
      echo -e "\n${YELLOW}Here is your $LANG language text in English from Whisper ASR!"
      echo -e "\n${GREEN}"
      cat "$TRANSLATED_TEXT"
      echo -e "\n${YELLOW}Your $LANG-English translated raw text output can be found in $TRANSLATED_TEXT${NOCOLOR}"
    else
      #echo -e "\n${YELLOW}If you want me to translate please type the two letter language ISO code${NOCOLOR}"
      #read TLANG
      if [ "$TLANG" ]; then
        whisperTranslate "$AUDIO" "$MIME" "$TLANG" | jq -r .text | tr . '\n' | sed 's/ //' > "$TRANSLATED_TEXT"
        echo -e "\n${YELLOW}Here is your translated $TLANG language text from Whisper ASR!"
        echo -e "\n${GREEN}"
        cat "$TRANSLATED_TEXT"
        echo -e "\n${NOCOLOR}"
      else
        echo -e "\n${YELLOW}Translation skipped${NOCOLOR}"
      fi
    fi
  else
    echo -e "${RED}Error - could not read audio $AUDIO${NOCOLOR}"
    exit 1
  fi
}

if [ "$2" ]; then
  SOURCE="$2"
else
  if [ "$ASR_PLATFORM" = "linux" ]; then
    SOURCE="default"
  else
    SOURCE="1"
  fi
fi

whisperTranslate() {
  curl --http1.1 -X 'POST' \
  "$BASE_URL/asr?task=translate&language=$3&output=json" \
  -u "$USER:$PASS" \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F "audio_file=@$1;type=$2"
}

# We need JQ
check_path jq

# We need curl
check_path curl

# We need file
check_path file

if [ -z "$1" ]; then
  do_asr
  exit
fi

case $1 in

clean)
  echo -e "${YELLOW}Cleaning old files${NOCOLOR}"
  do_clean
;;

list)
  if [ "$ASR_PLATFORM" = linux ]; then
    pactl list short sources
  else
    ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2> >(grep -A 10 'audio') | grep -v 'error'
  fi
;;

asr)
do_asr
;;

*)
  echo -e "${RED}Usage $0 asr|clean|list [PulseAudio capture device or local file]${NOCOLOR}"
  exit 1
;;

esac
