#!/usr/bin/env bash

NIX_BIN=/Users/matt/.nix-profile/bin/

bar=(
  position=top
  height=28
  margin=8
  y_offset=2
  corner_radius="$CORNER_RADIUS"
  border_color="$ACCENT_COLOR"
  border_width=2
  blur_radius=30
  color="$BAR_COLOR"
)

$NIX_BIN/sketchybar --bar "${bar[@]}"
