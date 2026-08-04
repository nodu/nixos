#!/usr/bin/env bash
# Unified i3-style Alt+Shift+hjkl movement: move (swap) the current tmux pane
# in a direction while inside the terminal, and fall through to AeroSpace
# window movement at pane edges (or when the focused app isn't a terminal).
# Bound in aerospace.toml. Sibling of tmux-nav.sh, which does the same for
# focus (Alt+hjkl).
#
# tmux itself tracks which client is focused (the "focused" client flag,
# fed by terminal focus events — requires `focus-events on`, set in
# home/shared/tmux.nix). A plain-shell terminal window leaves no client
# focused, so it falls through to window movement like any other app.
#
# swap-pane -d keeps the active-pane designation on the pane we moved, so
# focus follows the pane in the direction it travels (matching AeroSpace's
# `move`). The {left-of}/{down-of}/... targets are the pane spatially in that
# direction; they error at an edge, so we gate on the pane_at_* flag first and
# only fall through to AeroSpace when there's no neighbor to swap with.
#
# Usage: tmux-move.sh (left|down|up|right)
export PATH="/etc/profiles/per-user/matt/bin:/usr/bin:/bin"

dir="$1"
case "$dir" in
  left)  swap_target="{left-of}";  edge="pane_at_left"   ;;
  down)  swap_target="{down-of}";  edge="pane_at_bottom" ;;
  up)    swap_target="{up-of}";    edge="pane_at_top"    ;;
  right) swap_target="{right-of}"; edge="pane_at_right"  ;;
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
        exec tmux swap-pane -d -s "$pane_id" -t "$swap_target"
      fi
    fi
    ;;
esac

exec aerospace move "$dir"
