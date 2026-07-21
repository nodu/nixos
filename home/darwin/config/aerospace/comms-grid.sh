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
# Windows on workspace 4 beyond these four are left alone: they stay as
# extra columns to the left of the grid.
export PATH="/etc/profiles/per-user/matt/bin:/usr/bin:/bin"

WS=4
SLACK_ID='com.tinyspeck.slackmacgap'
TEAMS_ID='com.microsoft.teams2'
CAL_ID='com.google.Chrome.app.kjbdgfilnfhdoflbpgamdcdgpehopbep'

windows() {
  aerospace list-windows --all --format '%{window-id}|%{app-bundle-id}|%{window-title}'
}

find_win() { # $1: slack|teams|cal|gmail -> window id or empty
  case "$1" in
    slack) windows | awk -F'|' -v id="$SLACK_ID" '$2==id{print $1; exit}' ;;
    teams) windows | awk -F'|' -v id="$TEAMS_ID" '$2==id{print $1; exit}' ;;
    cal)   windows | awk -F'|' -v id="$CAL_ID"   '$2==id{print $1; exit}' ;;
    gmail) windows | awk -F'|' \
      '$2=="com.google.Chrome" && $3 ~ /10Four Mail/ && $3 !~ /Google Chrome/{print $1; exit}' ;;
  esac
}

launch() {
  case "$1" in
    slack) open -a 'Slack' ;;
    teams) open -a 'Microsoft Teams' ;;
    cal)   open -a "$HOME/Applications/Chrome Apps.localized/10Four - Google Calendar.app" ;;
    gmail) open -a "$HOME/Applications/Gmail Work.app" ;;
  esac
}

for app in slack teams cal gmail; do
  [ -n "$(find_win "$app")" ] || launch "$app"
done

# Wait for all four windows (Teams especially is slow to first window)
for _ in $(seq 100); do
  slack=$(find_win slack); teams=$(find_win teams)
  cal=$(find_win cal); gmail=$(find_win gmail)
  [ -n "$slack" ] && [ -n "$teams" ] && [ -n "$cal" ] && [ -n "$gmail" ] && break
  sleep 0.3
done
if [ -z "$slack" ] || [ -z "$teams" ] || [ -z "$cal" ] || [ -z "$gmail" ]; then
  echo "comms-grid: missing windows: slack=$slack teams=$teams cal=$cal gmail=$gmail" >&2
  exit 1
fi

for w in "$slack" "$teams" "$cal" "$gmail"; do
  aerospace move-node-to-workspace --window-id "$w" "$WS"
done

# Start from a clean flat row
aerospace flatten-workspace-tree --workspace "$WS"
aerospace layout --workspace "$WS" --root h_tiles

# Push each window to the right edge in turn, ending with the row
# [strays..., slack, teams, cal, gmail] regardless of starting order
n=$(aerospace list-windows --workspace "$WS" --count)
for w in "$slack" "$teams" "$cal" "$gmail"; do
  for _ in $(seq "$n"); do
    aerospace move --window-id "$w" --boundaries workspace --boundaries-action stop right
  done
done

# Fold the row into two columns; a plain `move up` then guarantees
# top/bottom order whichever way join-with stacked the pair
aerospace join-with --window-id "$teams" left
aerospace move --window-id "$slack" --boundaries workspace --boundaries-action stop up
aerospace join-with --window-id "$gmail" left
aerospace move --window-id "$cal" --boundaries workspace --boundaries-action stop up

aerospace balance-sizes --workspace "$WS"
aerospace workspace "$WS"
