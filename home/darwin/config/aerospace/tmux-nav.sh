#!/usr/bin/env bash
# Unified i3-style Alt+hjkl navigation: move between tmux panes while inside
# the terminal, and fall through to AeroSpace window focus at pane edges (or
# when the focused app isn't a terminal). Bound in aerospace.toml.
#
# tmux itself tracks which client is focused (the "focused" client flag,
# fed by terminal focus events — requires `focus-events on`, set in
# home/shared/tmux.nix). A plain-shell terminal window leaves no client
# focused, so it falls through to window focus like any other app.
#
# Usage: tmux-nav.sh (left|down|up|right)
export PATH="/etc/profiles/per-user/matt/bin:/usr/bin:/bin"

dir="$1"
case "$dir" in
  left)  pane_flag="-L"; edge="pane_at_left"   ;;
  down)  pane_flag="-D"; edge="pane_at_bottom" ;;
  up)    pane_flag="-U"; edge="pane_at_top"    ;;
  right) pane_flag="-R"; edge="pane_at_right"  ;;
  *) echo "usage: $0 left|down|up|right" >&2; exit 1 ;;
esac

app="$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null)"

case "$app" in
  Alacritty|Ghostty|kitty|Terminal)
    # The tmux client whose terminal window is focused, if any
    client="$(tmux list-clients -F '#{?#{m:*focused*,#{client_flags}},#{client_name},}' 2>/dev/null \
      | grep . | head -1)"
    if [ -n "$client" ]; then
      # Evaluate edge status against that client's active pane
      at_edge="$(tmux display -p -c "$client" "#{$edge}" 2>/dev/null)"
      if [ "$at_edge" = "0" ]; then
        pane_id="$(tmux display -p -c "$client" '#{pane_id}')"
        exec tmux select-pane "$pane_flag" -t "$pane_id"
      fi
    fi
    ;;
esac

exec aerospace focus "$dir"
