#!/usr/bin/env bash
# Move live Teams meeting windows from the comms workspace (4) to 3, next to
# Zoom/Meet. Run from aerospace.toml's on-window-detected rule for Teams.
#
# The rule can't match on the title itself: Teams creates the window before
# naming it, so at detection a meeting looks just like the main window. This
# polls for a few seconds so the title has time to settle.
#
# The main window's title is the section it's showing ("Chat", "Calls",
# "Calendar | Microsoft Teams", ...); anything else is a meeting. Only windows
# still on 4 are moved, so a meeting moved somewhere by hand stays there.
export PATH="/etc/profiles/per-user/matt/bin:/usr/bin:/bin"

TEAMS_ID='com.microsoft.teams2'
MAIN_RE='^(Activity|Chat|Teams|Calendar|Calling|Calls|OneDrive|Apps|Copilot|Communities|Files|Search|Microsoft Teams)?( \||$)'

for _ in $(seq 10); do
  sleep 1
  aerospace list-windows --all --format '%{window-id}|%{app-bundle-id}|%{workspace}|%{window-title}' |
    awk -F'|' -v id="$TEAMS_ID" '$2==id && $3=="4"' |
    while IFS='|' read -r wid _ _ title; do
      [[ $title =~ $MAIN_RE ]] && continue
      aerospace move-node-to-workspace --window-id "$wid" 3
    done
done
