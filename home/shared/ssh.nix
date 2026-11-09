# Shared SSH configuration
{ config, lib, pkgs, ... }:

let
  # One key pair, same name on every host; secrets/restore puts it in place
  identityFile = "~/.ssh/matt";

  # Peer addresses live in one place so the ssh blocks below and the mac's
  # /etc/hosts block cannot drift apart.
  meshPeers = import ../../modules/mesh-peers.nix;

  # ssh names that reach a peer besides its bare hostname.
  peerAliases = { baremetal = [ "baremetal-tunnel" ]; };

  # Fixed system paths because a Match line is an attribute name, which can't
  # refer to a store path.
  # Apple's nc: `-G` is its connect timeout (the nix nc on PATH ignores it).
  lanCheck = addr:
    if pkgs.stdenv.isDarwin
    then "/usr/bin/nc -z -G 1 ${addr} 22"
    else "/run/current-system/sw/bin/timeout 1 /run/current-system/sw/bin/bash -c '</dev/tcp/${addr}/22'";

  # Use the LAN whenever a peer answers there, otherwise fall through to the
  # Meshnet name in its Host block. Meshnet's links can go dead after the mac
  # sleeps.
  # Must precede the Host blocks: ssh keeps the first HostName it sees.
  lanMatches = lib.mapAttrs'
    (name: { lan, ... }:
      let hosts = [ name ] ++ peerAliases.${name} or [ ]; in
      lib.nameValuePair
        "Match originalhost ${lib.concatStringsSep "," hosts} exec \"${lanCheck lan} >/dev/null 2>&1\""
        (lib.hm.dag.entryBefore hosts { HostName = lan; }))
    meshPeers;

  # "<name>-mesh-ip" escape hatches: address a peer by its Meshnet IP directly,
  # bypassing name resolution entirely. Useful when DNS is the thing that's
  # broken -- which is exactly the failure the /etc/hosts block guards against.
  meshSettings = lib.mapAttrs'
    (name: { mesh, ... }: lib.nameValuePair "${name}-mesh-ip" {
      User = "matt";
      HostName = mesh;
      IdentityFile = identityFile;
    })
    meshPeers;
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "bitbucket.org" = {
        HostName = "bitbucket.org";
        IdentityFile = identityFile;
      };

      "github.com" = {
        HostName = "github.com";
        IdentityFile = identityFile;
        IdentitiesOnly = "yes";
      };

      "bau-slate-wifi" = {
        User = "matt";
        HostName = "192.168.8.8";
        IdentityFile = identityFile;
      };

      "bau-slate" = {
        User = "matt";
        HostName = "192.168.8.6";
        IdentityFile = identityFile;
      };

      "bau" = {
        User = "matt";
        HostName = "bau";
        HostKeyAlias = "bau";
        IdentityFile = identityFile;
      };

      "bau-att" = {
        User = "matt";
        HostName = "192.168.1.76";
        IdentityFile = identityFile;
      };

      "baremetal" = {
        User = "matt";
        HostName = "baremetal";
        # One known_hosts entry whether we arrive over the LAN or Meshnet; a
        # stranger at .20 on some other network fails the key check.
        HostKeyAlias = "baremetal";
        IdentityFile = identityFile;
      };
      "baremetal-tunnel" = {
        User = "matt";
        HostName = "baremetal";
        HostKeyAlias = "baremetal";
        IdentityFile = identityFile;
        LocalForward = [{
          bind.port = 3389;
          host.address = "localhost";
          host.port = 3389;
        }];
      };

      "base" = {
        User = "matt";
        HostName = "base";
        HostKeyAlias = "base";
        IdentityFile = identityFile;
      };

      "rpi3" = {
        User = "matt";
        HostName = "rpi3";
        IdentityFile = identityFile;
      };

      "moode" = {
        User = "pi";
        HostName = "192.168.0.102";
      };

      "fermentation-station" = {
        User = "pi";
        HostName = "192.168.0.4";
      };

      "*" = {
        IdentitiesOnly = "yes";
      };
    } // meshSettings // lanMatches;
  };
}

