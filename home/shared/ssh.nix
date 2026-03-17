# Shared SSH configuration
{ config, lib, pkgs, ... }:

let
  # Use the same key name across hosts; secrets/restore puts the key in place
  identityFile = if pkgs.stdenv.isDarwin then "~/.ssh/mac" else "~/.ssh/baremetal";
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

      "bau-mesh-ip" = {
        user = "matt";
        hostname = "100.105.37.182";
        identityFile = identityFile;
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
    };
  };
}

