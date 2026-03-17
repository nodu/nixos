#!/usr/bin/env bash

NIX_BIN=/Users/matt/.nix-profile/bin/

VOLUME=$(osascript -e 'output volume of (get volume settings)')

if [ "$SENDER" = "volume_change" ]; then
  VOLUME=$INFO

elif command -v betterdisplaycli 2>&1 >/dev/null; then
  if [ "$VOLUME" = "missing value" ]; then
    VOLUME=$(betterdisplaycli get -ddc -value -vcp=audioSpeakerVolume -displayWithMainStatus)
  fi
fi

case $VOLUME in
[6-9][0-9] | 100)
  ICON="􀊩"
  ;;
[3-5][0-9])
  ICON="􀊥"
  ;;
[1-9] | [1-2][0-9])
  ICON="􀊡"
  ;;
*) ICON="􀊣" ;;
esac

$NIX_BIN/sketchybar --set "$NAME" icon="$ICON" label="$VOLUME%"
