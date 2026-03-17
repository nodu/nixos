# Shared SSH configuration
{ config, lib, pkgs, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "bitbucket.org" = {
        hostname = "bitbucket.org";
        identityFile = "~/.ssh/baremetal";
      };

      "github.com" = {
        hostname = "github.com";
        identityFile = "~/.ssh/baremetal";
        extraOptions.IdentitiesOnly = "yes";
      };

      "bau-slate-wifi" = {
        user = "matt";
        hostname = "192.168.8.8";
        identityFile = "~/.ssh/baremetal";
      };

      "bau-slate" = {
        user = "matt";
        hostname = "192.168.8.6";
        identityFile = "~/.ssh/baremetal";
      };

      "bau" = {
        user = "matt";
        hostname = "bau";
        identityFile = "~/.ssh/baremetal";
      };

      "bau-kai" = {
        user = "matt";
        hostname = "192.168.0.6";
        identityFile = "~/.ssh/baremetal";
      };

      "bau-att" = {
        user = "matt";
        hostname = "192.168.1.76";
        identityFile = "~/.ssh/baremetal";
      };

      "bau-mesh-ip" = {
        user = "matt";
        hostname = "100.105.37.182";
        identityFile = "~/.ssh/baremetal";
      };

      "rpi3" = {
        user = "matt";
        hostname = "rpi3";
        identityFile = "~/.ssh/baremetal";
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
    };
  };
}

