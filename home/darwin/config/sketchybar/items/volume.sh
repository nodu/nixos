#!/usr/bin/env bash

NIX_BIN=/Users/matt/.nix-profile/bin/

$NIX_BIN/sketchybar --add item volume right \
  --set volume script="$PLUGIN_DIR/volume.sh" \
  --subscribe volume volume_change display_volume_change
