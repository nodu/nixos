# Shared GPG configuration
# pinentry defaults to curses (headless-friendly); GUI hosts can override with mkForce
{ config, lib, pkgs, ... }:

{
  programs.gpg = {
    enable = true;
    settings = {
      no-symkey-cache = false; # Allow caching of Symmetric Passphrases
    };
  };

  services.gpg-agent = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    # cache the keys forever so we don't get asked for a password until reboot
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
    pinentry.package = lib.mkDefault pkgs.pinentry-curses;
  };
}
