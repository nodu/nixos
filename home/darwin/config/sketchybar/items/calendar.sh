#!/usr/bin/env bash

NIX_BIN=/Users/matt/.nix-profile/bin/

$NIX_BIN/sketchybar --add item calendar right \
  --set calendar icon=􀧞 \
  update_freq=30 \
  script="$PLUGIN_DIR/calendar.sh"
