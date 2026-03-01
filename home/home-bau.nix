# Bau (RPi4) home-manager configuration

{ inputs, ... }:
{ config, lib, pkgs, unstable, opencode-packages, ... }:

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
  };

  # GPG agent uses pinentry-curses (default from shared/gpg.nix)
  # No override needed for headless

  home.packages = [
    # Add bau-specific packages here
    opencode-packages.opencode

  ];
}
