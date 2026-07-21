#!/usr/bin/env bash
# Arrange workspace 4 as a 2x2 comms grid, launching anything not running:
#
#   Slack    | Calendar (10Four PWA)
#   Teams    | Gmail Work
#
# Gmail Work is a chrome --app window, so it reports plain com.google.Chrome
# as its app-id; it's matched by the "10Four Mail" workspace name in the
# title, excluding regular browser windows (whose titles end in "Google
# Chrome - <profile>"). Bound in aerospace.toml; also runnable from a shell.
#
# If the grid is already intact this is a no-op beyond switching to the
# workspace: structure is verified with focus probes, which never move
# windows. A rebuild reads the tree order via --dfs-index and does only the
# swaps actually needed, so windows that are already in place don't move.
#
# Windows on workspace 4 beyond these four are left alone: they stay as
# extra columns to the left of the grid.
export PATH="/etc/profiles/per-user/matt/bin:/usr/bin:/bin"

WS=4
SLACK_ID='com.tinyspeck.slackmacgap'
TEAMS_ID='com.microsoft.teams2'
CAL_ID='com.google.Chrome.app.kjbdgfilnfhdoflbpgamdcdgpehopbep'

# One fetch resolves all four windows and their placement; sets globals.
# The title goes last in the format because titles can contain the `|`
# delimiter (Teams: "Chat | ... | Microsoft Teams"); fields $1-$5 stay fixed.
scan() {
  local list
  list=$(aerospace list-windows --all --format \
    '%{window-id}|%{app-bundle-id}|%{workspace}|%{window-parent-container-layout}|%{workspace-root-container-layout}|%{window-title}')
  slack=$(awk -F'|' -v id="$SLACK_ID" '$2==id{print $1; exit}' <<<"$list")
  teams=$(awk -F'|' -v id="$TEAMS_ID" '$2==id{print $1; exit}' <<<"$list")
  cal=$(awk -F'|' -v id="$CAL_ID"   '$2==id{print $1; exit}' <<<"$list")
  gmail=$(awk -F'|' \
    '$2=="com.google.Chrome" && $0 ~ /10Four Mail/ && $0 !~ /Google Chrome/{print $1; exit}' <<<"$list")
  # id -> "workspace|parent-layout|root-layout"
  placement=$(awk -F'|' '{print $1"|"$3"|"$4"|"$5}' <<<"$list")
}

launch() {
  case "$1" in
    slack) open -a 'Slack' ;;
    teams) open -a 'Microsoft Teams' ;;
    cal)   open -a "$HOME/Applications/Chrome Apps.localized/10Four - Google Calendar.app" ;;
    gmail) open -a "$HOME/Applications/Gmail Work.app" ;;
  esac
}

scan
[ -n "$slack" ] || launch slack
[ -n "$teams" ] || launch teams
[ -n "$cal" ]   || launch cal
[ -n "$gmail" ] || launch gmail

# Wait for all four windows (Teams especially is slow to first window)
for _ in $(seq 100); do
  [ -n "$slack" ] && [ -n "$teams" ] && [ -n "$cal" ] && [ -n "$gmail" ] && break
  sleep 0.3
  scan
done
if [ -z "$slack" ] || [ -z "$teams" ] || [ -z "$cal" ] || [ -z "$gmail" ]; then
  echo "comms-grid: missing windows: slack=$slack teams=$teams cal=$cal gmail=$gmail" >&2
  exit 1
fi

# --- Fast path: skip the rebuild when the grid is already intact ----------

# Cheap check from the scan data alone (no focus changes): all four on the
# workspace, root row horizontal, each window inside a vertical column.
placed_ok() {
  local w
  for w in "$slack" "$teams" "$cal" "$gmail"; do
    grep -q "^$w|$WS|v_tiles|h_tiles$" <<<"$placement" || return 1
  done
}

# Focus in a direction and report where it landed; never moves windows.
probe() { # $1 window-id, $2 direction
  aerospace focus --window-id "$1" >/dev/null 2>&1
  aerospace focus "$2" --boundaries workspace --boundaries-action stop >/dev/null 2>&1
  aerospace list-windows --focused --format '%{window-id}'
}

# Exact structure: each column is exactly its pair (nothing above the top
# window, nothing below the bottom one), calendar column right of slack.
grid_ok() {
  [ "$(probe "$slack" down)" = "$teams" ] || return 1
  [ "$(probe "$slack" up)" = "$slack" ] || return 1
  [ "$(probe "$teams" down)" = "$teams" ] || return 1
  [ "$(probe "$cal" down)" = "$gmail" ] || return 1
  [ "$(probe "$cal" up)" = "$cal" ] || return 1
  case "$(probe "$slack" right)" in "$cal" | "$gmail") return 0 ;; esac
  return 1
}

if placed_ok && grid_ok; then
  aerospace focus --window-id "$slack"
  exit 0
fi

# --- Rebuild ---------------------------------------------------------------

rebuild() {
for w in "$slack" "$teams" "$cal" "$gmail"; do
  aerospace layout --window-id "$w" tiling >/dev/null 2>&1
  aerospace move-node-to-workspace --window-id "$w" "$WS" >/dev/null 2>&1
done

aerospace workspace "$WS" >/dev/null 2>&1 # dfs-index below reads the focused workspace
aerospace flatten-workspace-tree --workspace "$WS"
aerospace layout --workspace "$WS" --root h_tiles >/dev/null 2>&1

# Read the flat row's left-to-right order (floating strays aren't in the
# tiling tree, so stop at the first out-of-range index)
order=()
i=0
while aerospace focus --dfs-index "$i" >/dev/null 2>&1; do
  order+=("$(aerospace list-windows --focused --format '%{window-id}')")
  i=$((i + 1))
done

# Swap $1 into row position $2, tracking the order so counts stay exact
place() {
  local id=$1 target=$2 cur k
  for k in "${!order[@]}"; do [ "${order[k]}" = "$id" ] && cur=$k; done
  while ((cur < target)); do
    aerospace move --window-id "$id" right
    order[cur]=${order[cur + 1]}; order[cur + 1]=$id; cur=$((cur + 1))
  done
  while ((cur > target)); do
    aerospace move --window-id "$id" left
    order[cur]=${order[cur - 1]}; order[cur - 1]=$id; cur=$((cur - 1))
  done
}

# Right edge of the row, in order: slack, teams, cal, gmail
n=${#order[@]}
place "$slack" $((n - 4))
place "$teams" $((n - 3))
place "$cal" $((n - 2))
place "$gmail" $((n - 1))

# Fold the row into two columns; a plain `move up` then guarantees
# top/bottom order whichever way join-with stacked the pair
aerospace join-with --window-id "$teams" left
aerospace move --window-id "$slack" --boundaries workspace --boundaries-action stop up
aerospace join-with --window-id "$gmail" left
aerospace move --window-id "$cal" --boundaries workspace --boundaries-action stop up

aerospace balance-sizes --workspace "$WS"
}

# A window can appear mid-rebuild (e.g. launching Gmail Work starts Chrome,
# which restores its other PWA windows onto this workspace) and invalidate
# the tracked row order — so verify the result and retry until it converges.
for _ in 1 2 3; do
  rebuild
  scan
  if placed_ok && grid_ok; then
    aerospace focus --window-id "$slack"
    exit 0
  fi
done
echo "comms-grid: layout did not converge after 3 attempts" >&2
exit 1
