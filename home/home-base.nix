# Desktop workstation (2x RTX 3090; ./base-gtx1080.nix adds the GTX 1080).
# Shared workstation config is in ./workstation.nix.
{ inputs, ... }:
{ config, lib, pkgs, ... }:

{
  imports = [
    (import ./workstation.nix { inherit inputs; })
    # (import ./base-gtx1080.nix { inherit inputs; }) # with hosts/base/gtx1080.nix
  ];

  home.stateVersion = "26.05";

  home.packages = [
    pkgs.nvtopPackages.nvidia
  ];

  # Open WebUI on baremetal connects at http://192.168.0.3:8888/v1; bau's
  # Traefik serves the web UI as unsloth.nodu.io.
  unsloth.server = {
    enable = true;
    model = "unsloth/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF";
    ggufVariant = "Q4_K_M";
  };

  # 34" 3440x1440 ultrawide is ~110 dpi; workstation.nix defaults to the
  # Framework's 220
  programs.rofi.extraConfig.dpi = 110;
}
