# NordVPN Meshnet watchdog (macOS)
#
# Meshnet often stops passing traffic after the Mac switches between USB
# ethernet and Wi-Fi, and toggling Meshnet off/on in the app fixes it. This
# agent probes Meshnet peers over TCP and does that toggle automatically.
#
#   meshnet-watchdog check     one health check
#   meshnet-watchdog toggle    toggle Meshnet now
#   log: ~/Library/Logs/meshnet-watchdog.log
#
# The toggle drives the NordVPN UI, so /usr/bin/osascript needs Accessibility
# (System Settings > Privacy & Security > Accessibility). TCC judges the process
# launchd started, so the toggle is its own agent with osascript as the program
# itself. That is also why this is a nix-darwin module: home-manager wraps every
# agent in `/bin/sh -c`, which makes TCC judge /bin/sh instead.
{ config, pkgs, ... }:

let
  meshPeers = import ../../modules/mesh-peers.nix;
  logFile = "/Users/${config.system.primaryUser}/Library/Logs/meshnet-watchdog.log";
  toggleLabel = "org.nixos.meshnet-toggle";

  meshnetWatchdog = pkgs.writeShellApplication {
    name = "meshnet-watchdog";
    runtimeEnv = {
      MESHNET_PEERS = "${meshPeers.bau.mesh}:22";
      MESHNET_TOGGLE = toggleLabel;
      MESHNET_LOG = logFile;
    };
    text = builtins.readFile ../../home/scripts/meshnet-watchdog.sh;
  };
in
{
  environment.systemPackages = [ meshnetWatchdog ];

  launchd.user.agents.meshnet-watchdog = {
    command = "${meshnetWatchdog}/bin/meshnet-watchdog";
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      StandardErrorPath = logFile;
    };
  };

  # Started on demand by the watchdog with `launchctl kickstart`. Set
  # ProgramArguments directly: `command` would add the /bin/sh wrapper.
  launchd.user.agents.meshnet-toggle.serviceConfig = {
    Label = toggleLabel;
    ProgramArguments = [ "/usr/bin/osascript" "${../../home/scripts/meshnet-toggle.applescript}" ];
    StandardOutPath = logFile;
    StandardErrorPath = logFile;
  };
}
