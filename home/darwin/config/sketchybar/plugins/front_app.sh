#!/usr/bin/env bash

NIX_BIN=/Users/matt/.nix-profile/bin/

if [ "$SENDER" = "front_app_switched" ]; then
  $NIX_BIN/sketchybar --set "$NAME" label="$INFO" icon="$("$CONFIG_DIR/plugins/icon_map_fn.sh" "$INFO")"
fi
