# Shared CLI utilities
{ config, lib, pkgs, unstable, ... }:

{
  options.cli = {
    enableHeavyPackages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include heavy CLI packages (fastfetch, imagemagick). Disable on constrained devices.";
    };
  };

  config.home.packages = [
    pkgs.nix-search-cli
    pkgs.rclone
    pkgs.fd
    pkgs.bat
    pkgs.gum
    pkgs.glow
    pkgs.fzf
    pkgs.gotop
    pkgs.btop
    pkgs.jq
    pkgs.jqp #jq playground tui
    pkgs.ripgrep
    pkgs.tree
    pkgs.zip
    pkgs.unzip
    pkgs.entr
    pkgs.killall
    pkgs.tealdeer
    pkgs.openpomodoro-cli
    pkgs.file
    pkgs.dnsutils
    pkgs.lazygit
    pkgs.difftastic
    pkgs.dust
    unstable.yt-dlp
  ] ++ lib.optionals config.cli.enableHeavyPackages [
    pkgs.fastfetch
    pkgs.imagemagick
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.lshw # Linux only
  ];
}
