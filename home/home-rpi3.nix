# RPi3 home-manager configuration - headless server
# Imports shared modules for shell, git, neovim, CLI tools, and GPG
# No GUI packages, no desktop entries, no theming

{ inputs, ... }:
{ config, lib, pkgs, unstable, ... }:

{
  imports = [
    inputs.defaults.homeManagerModules.default
    (import ./shared/neovim.nix { inherit inputs; })
    ./shared/shell.nix
    ./shared/git.nix
    ./shared/cli.nix
    ./shared/gpg.nix
    ./shared/ssh.nix
    ./shared/tmux.nix
  ];

  home.stateVersion = "25.11";

  xdg.enable = true;

  #---------------------------------------------------------------------
  # Programs
  #---------------------------------------------------------------------

  programs.defaults = {
    enable = true;
    network.enable = false; # wireshark-cli, nmap, etc. add ~500 MiB -- too heavy for Pi
  };

  # Disable heavy packages to keep closure small on the Pi's 8 GB SD card
  cli.enableHeavyPackages = false;      # neofetch (~285 MiB), imagemagick (~194 MiB)
  neovim.enableNodejs = false;          # nodejs_22 (~224 MiB) -- no Copilot on Pi

  # GPG agent uses pinentry-curses (default from shared/gpg.nix)
  # No override needed for headless

  home.packages = [
    # Add rpi3-specific packages here

    # Gaggimate
    pkgs.esptool
  ];
}
