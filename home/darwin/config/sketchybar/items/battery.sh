#!/usr/bin/env bash

NIX_BIN=/Users/matt/.nix-profile/bin/

$NIX_BIN/sketchybar --add item battery right \
  --set battery update_freq=120 \
  script="$PLUGIN_DIR/battery.sh" \
  --subscribe battery system_woke power_source_change
