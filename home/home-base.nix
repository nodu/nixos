# Desktop workstation (RTX 3090 + GTX 1080). Shared workstation config is in
# ./workstation.nix.
{ inputs, ... }:
{ config, lib, pkgs, ... }:

{
  imports = [
    (import ./workstation.nix { inherit inputs; })
  ];

  home.stateVersion = "26.05";

  home.packages = [
    pkgs.nvtopPackages.nvidia
  ];

  # 34" 3440x1440 ultrawide is ~110 dpi; workstation.nix defaults to the
  # Framework's 220
  programs.rofi.extraConfig.dpi = 110;
}
