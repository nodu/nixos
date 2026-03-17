# Shared CLI utilities
{ config, lib, pkgs, ... }:

{
  home.packages = [
    # TODO: audit and narrow this list.
    pkgs.nix-search-cli
    pkgs.neofetch
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
    pkgs.entr # maybe not needed
    pkgs.killall
    pkgs.tealdeer
    pkgs.openpomodoro-cli
    pkgs.file
    pkgs.dnsutils
    pkgs.lazygit
    pkgs.difftastic
    pkgs.dust
    pkgs.imagemagick
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.lshw # Linux only
  ];
}
