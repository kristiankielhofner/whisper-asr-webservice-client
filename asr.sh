#!/bin/bash

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

# Cleanup
rm -rf "$AUDIO" "$RESULTS" "$TEXT" "$TRANSLATED_TEXT"

if [ "$2" ]; then
  SOURCE="$2"
else
  SOURCE="default"
fi

check_path() {
  [[ $(type -P "$1") ]] || { echo -e "${RED}Error - you need to install $1${NOCOLOR}" 1>&2; exit 1; }
}

whisperTranslate() {
  if [ -z $3 ]; then
    DEST_LANG="en"
  else
    DEST_LANG="$3"
  fi
  curl -X 'POST' \
  "$BASE_URL/asr?task=translate&language=$DEST_LANG&output=json" \
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

case $1 in

list)
  pactl list short sources
;;

asr)
  if [ ! -r "$SOURCE" ]; then
    check_path ffmpeg
    echo -e "${YELLOW}Recording audio with ffmpeg - CTRL+C when you want to stop capturing and submit${NOCOLOR}"
    ffmpeg -f pulse -i "$SOURCE" -compression_level 12 -ar 16000 -ac 1 "$AUDIO"
  else
    echo -e "${YELLOW}Using provided file $SOURCE as input${NOCOLOR}"
    export AUDIO="$SOURCE"
  fi

  if [ -f "$AUDIO" ]; then
    MIME=$(file --mime-type -b "$AUDIO")
    echo -e "${YELLOW}Submitting to $BASE_URL - please hold but ASR time is roughly 20x real-time${NOCOLOR}"
    curl -X 'POST' \
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
      whisperTranslate "$AUDIO" "$MIME" | jq -r .text | tr . '\n' | sed 's/ //' > "$TRANSLATED_TEXT"
      echo -e "\n${YELLOW}Here is your $LANG language text in English from Whisper ASR!"
      echo -e "\n${GREEN}"
      cat "$TRANSLATED_TEXT"
      echo -e "\n${YELLOW}Your $LANG-English translated raw text output can be found in $TRANSLATED_TEXT${NOCOLOR}"
    fi

  else
    echo -e "${RED}Error - could not read audio $AUDIO${NOCOLOR}"
    exit 1
  fi

;;

*)
  echo -e "${RED}Usage $0 list|asr [PulseAudio capture device or local file]${NOCOLOR}"
  exit 1
;;

esac
