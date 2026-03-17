#!/usr/bin/env bash

NIX_BIN=/Users/matt/.nix-profile/bin/

CURRENT_MODE=$($NIX_BIN/aerospace list-modes --current)

if [ "$CURRENT_MODE" == "main" ]; then
  $NIX_BIN/sketchybar --set "$NAME" \
    drawing=off
else
  $NIX_BIN/sketchybar --set "$NAME" \
    drawing=on
fi
