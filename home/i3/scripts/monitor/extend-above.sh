#!/bin/sh

# Detect external monitor and build --off args for all other DP outputs
EXT=$(xrandr | grep ' connected' | grep -v eDP | awk '{print $1}')
OFF_ARGS=$(xrandr | grep '^\(DP\|HDMI\)' | grep -v "^${EXT} " | awk '{print "--output", $1, "--off"}')

if [ -z "$EXT" ]; then
	dunstify "No external monitor detected"
	exit 1
fi

xrandr \
	--output "$EXT" --primary --mode 3440x1440 --rate 120 --pos 0x0 --rotate normal \
	--output eDP-1 --mode 2256x1504 --rate 60 --pos 592x1440 --rotate normal --scale 1x1 \
	$OFF_ARGS

dunstify "External Monitor: Above (120Hz)"
