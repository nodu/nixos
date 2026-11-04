#!/usr/bin/env bash
# Enter passthrough mode while a remote-session app is focused so every alt-*
# chord reaches the remote host, and drop back to main when focus leaves it.
# Run from aerospace.toml's on-focus-changed. alt-shift-backtick still toggles
# by hand; the mode is only re-evaluated on the next focus change.
export PATH="/etc/profiles/per-user/matt/bin:/usr/bin:/bin"

PASSTHROUGH_RE='^com\.moonlight-stream\.Moonlight$'

app=$(aerospace list-windows --focused --format '%{app-bundle-id}' 2>/dev/null)
mode=$(aerospace list-modes --current)

if [[ $app =~ $PASSTHROUGH_RE ]]; then
  [[ $mode == main ]] && aerospace mode passthrough
elif [[ $mode == passthrough ]]; then
  aerospace mode main
fi
