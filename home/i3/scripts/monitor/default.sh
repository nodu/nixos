#!/bin/sh

# Build --off args for all DP/HDMI outputs (including ghost outputs)
OFF_ARGS=$(xrandr | grep '^\(DP\|HDMI\)' | awk '{print "--output", $1, "--off"}')

xrandr \
	--output eDP-1 --primary --mode 2256x1504 --rate 60 --pos 0x0 --rotate normal --scale 1x1 \
	$OFF_ARGS

dunstify "External Monitor: Off"
