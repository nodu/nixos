# Watches NordVPN Meshnet and toggles it off/on when peers stop answering.
# NordVPN for macOS has no CLI, so the toggle drives the app UI via osascript,
# run as its own launchd agent (see hosts/mac/meshnet-watchdog.nix).
#
#   meshnet-watchdog            run forever (launchd)
#   meshnet-watchdog check      one health check, exit 0 if healthy
#   meshnet-watchdog toggle     toggle Meshnet off/on now
#
# Configured by the wrapper in hosts/mac/meshnet-watchdog.nix:
#   MESHNET_PEERS   space-separated host:port; healthy if any accepts TCP
#                   (bau drops ICMP over Meshnet, so ping is useless here)
#   MESHNET_LOG     log file (default ~/Library/Logs/meshnet-watchdog.log)
#   MESHNET_TOGGLE  launchd label of the agent that flips the Meshnet switch;
#                   empty = log only

INTERNET=1.1.1.1:443
INTERVAL=15        # seconds between checks
FAILS_NEEDED=3     # consecutive failures before toggling
COOLDOWN=180       # seconds to wait after a toggle before judging again
MAX_TOGGLES=2      # per outage; after that only log, until recovery or a network change
LOG=${MESHNET_LOG:-$HOME/Library/Logs/meshnet-watchdog.log}

read -r -a peers <<< "$MESHNET_PEERS"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

# macOS nc, for -G (connect timeout)
tcp_ok() { /usr/bin/nc -z -G 3 "${1%:*}" "${1##*:}" >/dev/null 2>&1; }

mesh_ok() {
  local p
  for p in "${peers[@]}"; do tcp_ok "$p" && return 0; done
  return 1
}

primary_if() { /sbin/route -n get default 2>/dev/null | awk '/interface:/{print $2}'; }

notify() { /usr/bin/osascript -e "display notification \"$1\" with title \"Meshnet watchdog\"" >/dev/null 2>&1 || true; }

toggle() {
  if [[ -z ${MESHNET_TOGGLE:-} ]]; then
    log "would toggle meshnet, but no toggle script is configured"
    return
  fi
  log "toggling meshnet"
  launchctl kickstart "gui/$(id -u)/$MESHNET_TOGGLE" >> "$LOG" 2>&1 \
    || log "could not start $MESHNET_TOGGLE"
}

case ${1:-} in
  check) mesh_ok; exit ;;
  toggle) toggle; exit ;;
esac

fails=0
toggles=0
last_if=$(primary_if)
log "started, primary=$last_if peers=${peers[*]}"
while true; do
  cur_if=$(primary_if)
  if [[ $cur_if != "$last_if" ]]; then
    log "primary interface $last_if -> $cur_if"
    last_if=$cur_if
    fails=0
    toggles=0
    sleep 10  # let NordLynx settle before judging
  fi

  if mesh_ok; then
    (( fails > 0 || toggles > 0 )) && log "meshnet recovered after $fails failed checks, $toggles toggles"
    fails=0
    toggles=0
  elif tcp_ok "$INTERNET"; then
    (( ++fails ))
    if (( toggles < MAX_TOGGLES )); then
      log "meshnet peers unreachable ($fails/$FAILS_NEEDED)"
      if (( fails >= FAILS_NEEDED )); then
        toggle
        (( ++toggles ))
        fails=0
        sleep "$COOLDOWN"
        continue
      fi
    elif (( fails == 1 )); then
      # Toggling here did not help, so the fault is likely on the peer's side.
      log "still unreachable after $toggles toggles; giving up until recovery or a network change"
      notify "Still unreachable after $toggles toggles. Not toggling again until it recovers or the network changes."
    fi
  fi
  sleep "$INTERVAL"
done
