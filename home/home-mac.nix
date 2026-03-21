# macOS home-manager configuration
{ inputs, ... }:
{ config, lib, pkgs, unstable, opencode-packages, ... }:

{
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.defaults.homeManagerModules.default
    (import ./shared/neovim.nix { inherit inputs; })
    ./shared/shell.nix
    ./shared/git.nix
    ./shared/cli.nix
    ./shared/gpg.nix
    ./shared/ssh.nix
    ./shared/tmux.nix
    ./shared/alacritty.nix
    ./darwin/darwin.nix
  ];

  colorScheme = inputs.nix-colors.colorSchemes.catppuccin-mocha;

  home.stateVersion = "23.11";
  home.enableNixpkgsReleaseCheck = false;

  xdg.enable = true;

  #----- Programs -----
  programs.defaults = {
    enable = true;
    basic.enable = true; # unrar-free doesn't build on aarch64-darwin
    git.enable = true;
    network.enable = true; # iproute2/wireshark in defaults are Linux-only
  };

  # Marked broken Oct 20, 2022 check later to remove this
  # https://github.com/nix-community/home-manager/issues/3344
  manual.manpages.enable = false;

  #----- Alacritty (macOS-specific overrides; shared config in ./shared/alacritty.nix) -----
  programs.alacritty.settings = {
    font.size = 14;
    # Treat Option as Alt/Meta so escape sequences (word-jump, delete-word, etc.) work
    window.option_as_alt = "Both";
    # Fix for shell path when launching from desktop
    terminal.shell.program = "${pkgs.zsh}/bin/zsh";
  };

  #----- macOS-specific packages -----
  home.packages = [
    # pkgs.bun
    # pkgs.fnm
    # pkgs.yarn
    # pkgs.postgresql
    # pkgs.awscli2
    # pkgs.zulu11
    # pkgs.cargo
    # pkgs.nodejs_22
    pkgs.gh
    opencode-packages.opencode
  ];
}
