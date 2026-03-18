# macOS home-manager configuration
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
    ./darwin/darwin.nix
  ];

  home.stateVersion = "23.11";
  home.enableNixpkgsReleaseCheck = false;

  xdg.enable = true;

  #----- Programs -----
  programs.defaults = {
    enable = true;
    basic.enable = false; # unrar-free doesn't build on aarch64-darwin
    git.enable = true;
    network.enable = false; # iproute2/wireshark in defaults are Linux-only
  };

  # Marked broken Oct 20, 2022 check later to remove this
  # https://github.com/nix-community/home-manager/issues/3344
  manual.manpages.enable = false;

  #----- Alacritty (macOS-specific color scheme + font size) -----
  programs.alacritty = {
    enable = true;
    settings = {
      cursor.style = "Block";

      # Fix for shell path when launching from desktop
      terminal.shell = {
        program = "${pkgs.zsh}/bin/zsh";
      };

      font = {
        normal = {
          family = "Hack Nerd Font";
          style = "Regular";
        };
        size = 14;
      };

      keyboard.bindings = [
        { key = "V"; mods = "Alt"; action = "ToggleViMode"; }
        { key = "F"; mods = "Shift|Alt"; action = "SearchBackward"; }
      ];

      colors = {
        primary = {
          background = "0x1f2528";
          foreground = "0xc0c5ce";
        };
        normal = {
          black = "0x1f2528";
          red = "0xec5f67";
          green = "0x99c794";
          yellow = "0xfac863";
          blue = "0x6699cc";
          magenta = "0xc594c5";
          cyan = "0x5fb3b3";
          white = "0xc0c5ce";
        };
        bright = {
          black = "0x65737e";
          red = "0xec5f67";
          green = "0x99c794";
          yellow = "0xfac863";
          blue = "0x6699cc";
          magenta = "0xc594c5";
          cyan = "0x5fb3b3";
          white = "0xd8dee9";
        };
      };
    };
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
