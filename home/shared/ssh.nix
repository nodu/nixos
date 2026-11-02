# Shared SSH configuration
{ config, lib, pkgs, ... }:

let
  # One key pair, same name on every host; secrets/restore puts it in place
  identityFile = "~/.ssh/matt";

  # Meshnet addresses live in one place so the ssh blocks below and the mac's
  # /etc/hosts block cannot drift apart.
  meshPeers = import ../../modules/mesh-peers.nix;

  # "<name>-mesh-ip" escape hatches: address a peer by its Meshnet IP directly,
  # bypassing name resolution entirely. Useful when DNS is the thing that's
  # broken -- which is exactly the failure the /etc/hosts block guards against.
  # baremetal's wired LAN address at home. Meshnet's link to it goes dead after
  # the mac sleeps, so prefer the LAN whenever baremetal answers there.
  baremetalLan = "192.168.0.20";

  meshSettings = lib.mapAttrs'
    (name: addr: lib.nameValuePair "${name}-mesh-ip" {
      User = "matt";
      HostName = addr;
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
        IdentityFile = identityFile;
      };

      "bau-kai" = {
        User = "matt";
        HostName = "192.168.0.6";
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
      "baremetal-local" = {
        User = "matt";
        HostName = "baremetal.local";
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

      # Wired LAN address it had under Ubuntu; reserve it in the router.
      # TODO: switch to the Meshnet name once base is registered, like baremetal.
      "base" = {
        User = "matt";
        HostName = "192.168.0.3";
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
    } // meshSettings // lib.optionalAttrs pkgs.stdenv.isDarwin {
      # Must precede the Host blocks: ssh keeps the first HostName it sees.
      # Apple's nc: `-G` is its connect timeout (the nix nc on PATH ignores it).
      "Match originalhost baremetal,baremetal-tunnel exec \"/usr/bin/nc -z -G 1 ${baremetalLan} 22 >/dev/null 2>&1\"" =
        lib.hm.dag.entryBefore [ "baremetal" "baremetal-tunnel" ] {
          HostName = baremetalLan;
        };
    };
  };
}

