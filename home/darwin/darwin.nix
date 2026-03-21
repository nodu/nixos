# macOS WM configuration: aerospace, sketchybar, karabiner, jankyborders
{ config, lib, pkgs, unstable, ... }:

{
  home.packages = [
    unstable.aerospace
    pkgs.jankyborders
    pkgs.sketchybar
    pkgs.sketchybar-app-font
  ];

  # Symlink config directories via mkOutOfStoreSymlink so they remain mutable
  # (aerospace/sketchybar configs reference each other and the nix store path)
  xdg.configFile = {
    "aerospace/".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/nixos/home/darwin/config/aerospace";
    "sketchybar/".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/nixos/home/darwin/config/sketchybar";
    "karabiner/karabiner.json".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/nixos/home/darwin/config/karabiner.json";
  };
}
