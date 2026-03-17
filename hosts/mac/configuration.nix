# macOS (nix-darwin) system configuration
{ config, pkgs, lib, unstable, ... }:

let
  user = "matt";
in
{
  #----- Nix Settings -----
  nix = {
    package = pkgs.nix;

    settings = {
      trusted-users = [ "@admin" "${user}" ];
      substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
      trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
    };

    gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 2; Minute = 0; };
      options = "--delete-older-than 30d";
    };

    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  #----- nixpkgs -----
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
    allowUnsupportedSystem = true;
  };

  #----- System -----
  system = {
    checks.verifyNixPath = false;
    primaryUser = user;
    stateVersion = 6;

    defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;

        KeyRepeat = 2;
        InitialKeyRepeat = 15;

        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.swipescrolldirection" = false;
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.sound.beep.feedback" = 0;
      };

      dock = {
        autohide = true;
        show-recents = false;
        launchanim = true;
        orientation = "bottom";
        tilesize = 48;
      };

      # TODO: check if I like this behaviour
      finder = {
        # _FXShowPosixPathInTitle = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
    };
  };

  #----- Fonts -----
  fonts.packages = [
    pkgs.nerd-fonts.hack
  ];

  #----- User -----
  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.zsh;
  };

  #----- Homebrew -----
  homebrew = {
    enable = true;
    onActivation.cleanup = "uninstall";

    casks = [
      "docker-desktop"
      "google-chrome"
      "vlc"
      "spotify"
      "karabiner-elements"
      "claude"
      "pgadmin4"
      "opencode-desktop"
      "nordvpn"
      "slack"
      "microsoft-teams"
      "zoom"
      "handy"
      "bitwarden"
    ];

    brews = [
      # Add brews here as needed
    ];
  };
}
