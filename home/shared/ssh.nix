# Shared SSH configuration
{ config, lib, pkgs, ... }:

let
  # Use the same key name across hosts; secrets/restore puts the key in place
  identityFile = if pkgs.stdenv.isDarwin then "~/.ssh/mac" else "~/.ssh/baremetal";

  # Meshnet addresses live in one place so the ssh blocks below and the mac's
  # /etc/hosts block cannot drift apart.
  meshPeers = import ../../modules/mesh-peers.nix;

  # "<name>-mesh-ip" escape hatches: address a peer by its Meshnet IP directly,
  # bypassing name resolution entirely. Useful when DNS is the thing that's
  # broken -- which is exactly the failure the /etc/hosts block guards against.
  meshMatchBlocks = lib.mapAttrs'
    (name: addr: lib.nameValuePair "${name}-mesh-ip" {
      user = "matt";
      hostname = addr;
      identityFile = identityFile;
    })
    meshPeers;
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "bitbucket.org" = {
        hostname = "bitbucket.org";
        identityFile = identityFile;
      };

      "github.com" = {
        hostname = "github.com";
        identityFile = identityFile;
        extraOptions.IdentitiesOnly = "yes";
      };

      "bau-slate-wifi" = {
        user = "matt";
        hostname = "192.168.8.8";
        identityFile = identityFile;
      };

      "bau-slate" = {
        user = "matt";
        hostname = "192.168.8.6";
        identityFile = identityFile;
      };

      "bau" = {
        user = "matt";
        hostname = "bau";
        identityFile = identityFile;
      };

      "bau-kai" = {
        user = "matt";
        hostname = "192.168.0.6";
        identityFile = identityFile;
      };

      "bau-att" = {
        user = "matt";
        hostname = "192.168.1.76";
        identityFile = identityFile;
      };

      "baremetal" = {
        user = "matt";
        hostname = "baremetal";
        identityFile = identityFile;
      };

      "baremetal-tunnel" = {
        user = "matt";
        hostname = "baremetal";
        identityFile = identityFile;
        localForwards = [{
          bind.port = 3389;
          host.address = "localhost";
          host.port = 3389;
        }];
      };

      "rpi3" = {
        user = "matt";
        hostname = "rpi3";
        identityFile = identityFile;
      };

      "moode" = {
        user = "pi";
        hostname = "192.168.0.102";
      };

      "fermentation-station" = {
        user = "pi";
        hostname = "192.168.0.4";
      };

      "*" = {
        extraOptions.IdentitiesOnly = "yes";
      };
    } // meshMatchBlocks;
  };
}

