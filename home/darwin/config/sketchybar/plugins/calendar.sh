#!/usr/bin/env bash

NIX_BIN=/Users/matt/.nix-profile/bin/

$NIX_BIN/sketchybar --set $NAME label="$(date +'%a %d %b %I:%M %p')"
