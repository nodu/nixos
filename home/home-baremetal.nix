# Order 5
# Framework 13 AMD. Shared workstation config is in ./workstation.nix.
{ inputs, ... }:
{ config, lib, pkgs, unstable, ... }:

{
  imports = [
    (import ./workstation.nix { inherit inputs; })
  ];

  # Home-manager 22.11 requires this be set. We never set it so we have
  # to use the old state version.
  home.stateVersion = "23.05";

  home.packages = [
    # GPU (Radeon 780M)
    pkgs.amdgpu_top
    pkgs.lact
    pkgs.corectrl
  ];
}
