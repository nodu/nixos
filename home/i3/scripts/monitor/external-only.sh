#!/bin/sh

# Detect external monitor and build --off args for all other DP outputs
EXT=$(xrandr | grep ' connected' | grep -v eDP | awk '{print $1}')
OFF_ARGS=$(xrandr | grep '^\(DP\|HDMI\)' | grep -v "^${EXT} " | awk '{print "--output", $1, "--off"}')

if [ -z "$EXT" ]; then
	dunstify "No external monitor detected"
	exit 1
fi

xrandr \
	--output eDP-1 --off \
	--output "$EXT" --primary --mode 3440x1440 --rate 120 --pos 0x0 --rotate normal \
	$OFF_ARGS

dunstify "External Monitor: Only (120Hz)"
