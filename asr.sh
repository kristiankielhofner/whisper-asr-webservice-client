#!/bin/bash

# ASR client
# TODO: Investigate HTTP2 failures and stalls on mac
# TODO: CLEAN UP

# Define output files

if [ $ASR_OUT ]; then
  TEMP_LOCATION=$ASR_OUT
else
  TEMP_LOCATION="/tmp/asr.$RANDOM"
fi

RESULTS=$TEMP_LOCATION.json
TEXT=$TEMP_LOCATION.txt

# If we detect languages other than english automatically translate and save here
TRANSLATED_TEXT=$TEMP_LOCATION-translated.txt

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

if [ -r .config ]; then
  . .config
fi

if [ -z "$BASE_URL" ]; then
  echo -e "${RED}Need to define BASE_URL - exiting${NOCOLOR}"
  exit 1
fi

if [ -z "$RECORD_FORMAT" ]; then
  RECORD_FORMAT="flac"
fi

if [ -z "$USER" -o -z "$PASS" ]; then
  USER="none"
  PASS="none"
fi

if [ -z "$MODEL" ]; then
  MODEL="base"
fi

if [ -z "$BEAM_SIZE" ]; then
  BEAM_SIZE="2"
fi

if [ -z "$DETECT_LANGUAGE" ]; then
  DETECT_LANGUAGE="False"
fi

echo -e "${YELLOW}Using model $MODEL with beam size $BEAM_SIZE and language detection $DETECT_LANGUAGE${NOCOLOR}"

WHISPER_URL="$BASE_URL"

AUDIO="asr.$RECORD_FORMAT"

check_path() {
  [[ $(type -P "$1") ]] || { echo -e "${RED}Error - you need to install $1${NOCOLOR}" 1>&2; exit 1; }
}

if [ "$OSTYPE" = "linux-gnu" ]; then
  ASR_PLATFORM="linux"
else
  ASR_PLATFORM="mac"
fi

# Cleanup
do_clean() {
  rm -rf "$AUDIO" "$RESULTS" "$TEXT" "$TRANSLATED_TEXT" /tmp/asr.*
}

show_usage() {
  echo -e "${RED}Usage $0:

  asr [file or audio device identifier] - do ASR. If you don't specify a device or file we'll try to use your microphone
  list - list available audio devices for capture and ASR
  clean - clean old files${NOCOLOR}"
  exit 1
}

do_asr() {
  if [ ! -r "$SOURCE" ]; then
    check_path ffmpeg
    do_clean
    echo -e "${YELLOW}Recording audio with ffmpeg - CTRL+C when you want to stop capturing and submit ${RED}BUT WAIT FOR FFMPEG OUTPUT${NOCOLOR}"
    if [ "$ASR_PLATFORM" = "linux" ]; then
      ffmpeg -hide_banner -f pulse -i "$SOURCE" -ar 16000 -ac 1 "$AUDIO"
    else
      ffmpeg -hide_banner -f avfoundation -i ":$SOURCE" -ar 16000 -ac 1 "$AUDIO"
    fi
  else
    echo -e "${YELLOW}Using provided file $SOURCE as input${NOCOLOR}"
    export AUDIO="$SOURCE"
  fi

  if [ -f "$AUDIO" ]; then
    MIME=$(file --mime-type -b "$AUDIO")
    echo -e "${YELLOW}Submitting to $WHISPER_URL - please hold: ASR time is usually 10x faster than real-time${NOCOLOR}"
    curl -X 'POST' \
    "$WHISPER_URL/asr?task=transcribe&output=json&model=$MODEL&beam_size=$BEAM_SIZE&detect_language=$DETECT_LANGUAGE" \
    -u "$USER:$PASS" \
    -H 'accept: application/json' \
    -H 'Content-Type: multipart/form-data' \
    -F "audio_file=@$AUDIO;type=$MIME" > "$RESULTS"

    LANG=$(cat "$RESULTS" | jq -r .language)
    HUMAN_LANG=$(cat langmap.json | jq -r --arg code "$LANG" '.[] | select(.code == $code) | {name} | .name')
    echo -e "\n${YELLOW}Here is your $HUMAN_LANG language text from ASR!"
    echo -e "${GREEN}"
    # Unnecessary use of cat award
    cat "$RESULTS" | jq -r .text | tee "$TEXT"

    echo -e "\n${YELLOW}Your raw text output can be found in $TEXT"

    if `cat "$RESULTS" | jq 'has("translation")' > /dev/null 2> /dev/null`; then
      TRANSLATION=$(cat "$RESULTS" | jq -r .translation)

       if [ "$TRANSLATION" != "null" ]; then
         echo -e "\n${YELLOW}Detected non-English language $HUMAN_LANG - translation${NOCOLOR}"
         echo -e "\n${GREEN}$TRANSLATION"
       fi
    fi

    if `cat "$RESULTS" | jq 'has("normalized")' > /dev/null 2> /dev/null`; then
      NORMALIZED=$(cat "$RESULTS" | jq -r .normalized)

       if [ "$NORMALIZED" != "null" ]; then
         echo -e "\n${YELLOW}Detected normalized text ${NOCOLOR}"
         echo -e "\n${GREEN}$NORMALIZED"
       fi
    fi

    if `cat "$RESULTS" | jq 'has("used_macros")' > /dev/null 2> /dev/null`; then
      USED_MACROS=$(cat "$RESULTS" | jq -r .used_macros)

       if [ "$USED_MACROS" != "null" ]; then
         echo -e "\n${YELLOW}NOTICE: Detected and used voice macro $USED_MACROS ${NOCOLOR}"
       fi
    fi

    INFER_TIME=$(cat "$RESULTS" | jq -r .infer_time)
    INFER_SPEEDUP=$(cat "$RESULTS" | jq -r .infer_speedup)
    AUDIO_DURATION=$(cat "$RESULTS" | jq -r .audio_duration)
    echo -e "${YELLOW}Input audio is $AUDIO_DURATION ms and infer time is $INFER_TIME ms - speedup of $INFER_SPEEDUP x"

    # Reset terminal color back to none when done
    echo -e "${NOCOLOR}"

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
    SOURCE=$(ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2> >(grep -A 10 'audio') | grep -v 'error' | grep Mac | grep Microphone | cut -d']' -f2 | tr -d '[')
    echo "Using Mac source device $SOURCE"
  fi
fi

# We need JQ
check_path jq

# We need curl
check_path curl

# We need file
check_path file

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

dist)
  do_clean
  cd ..
  tar -cvzf whisper.tar.gz --exclude whisper/.git whisper
;;

*)
  show_usage
;;

esac
