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
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 2; Minute = 0; };
      options = "--delete-older-than 30d";
    };

    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    # Linux builder VM for building aarch64-linux configs (rpi3, bau) on macOS
    linux-builder.enable = true;
  };

  # Don't run the linux-builder VM persistently -- it's only needed for ad-hoc
  # rpi3/bau builds. The Makefile targets start/stop it on demand.
  launchd.daemons.linux-builder.serviceConfig = {
    KeepAlive = lib.mkForce false;
    RunAtLoad = lib.mkForce false;
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
        AppleInterfaceStyle = "Dark";
        # Keyboard navigation: Tab moves focus between controls (2 = enabled on Sonoma+)
        AppleKeyboardUIMode = 2;

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
        # Group windows by application in Mission Control (required for AeroSpace)
        expose-group-apps = true;

        persistent-apps = [
          "/Users/${user}/Applications/Home Manager Trampolines/Alacritty.app"
          "/Applications/Google Chrome.app"
          "/Applications/Slack.app"
          "/Applications/Spotify.app"
          "/Applications/Bitwarden.app"
          "/System/Applications/Games.app"
        ];

        persistent-others = [
          "/Users/${user}/Downloads"
        ];
      };

      finder = {
        ShowPathbar = true;
        ShowStatusBar = true;
        # Default to list view
        FXPreferredViewStyle = "Nlsv";
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
        # Disable three-finger-tap "Look up"
        TrackpadThreeFingerTapGesture = 0;
      };

      WindowManager = {
        # Don't reveal desktop when clicking wallpaper
        EnableStandardClickToShowDesktop = false;
      };

      CustomUserPreferences = {
        AeroSpaceApp = {
          menuBarStyle = "i3";
        };
        # Disable "Displays have separate Spaces" for better AeroSpace stability
        # and multi-monitor support. Requires logout to take effect.
        # See: https://nikitabobko.github.io/AeroSpace/guide#a-note-on-displays-have-separate-spaces
        "com.apple.spaces" = {
          spans-displays = true;
        };
        # Disable Spotlight keyboard shortcuts so Raycast can claim Cmd+Space
        "com.apple.symbolichotkeys" = {
          AppleSymbolicHotKeys = {
            # 64 = Spotlight Search (Cmd+Space)
            "64" = { enabled = false; };
            # 65 = Finder Search Window (Cmd+Option+Space)
            "65" = { enabled = false; };
          };
        };
      };
    };
  };

  #----- Power -----
  power.sleep.computer = "never";

  #----- Security -----
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

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
    # Pass --force to `brew bundle` so cleanup runs non-interactively during
    # `make mac/switch` (otherwise Homebrew prompts `Do you want to proceed
    # with the cleanup? [y/n]`).
    onActivation.extraFlags = [ "--force" ];

    # Declare the baseline Homebrew taps so cleanup does not try (and fail) to
    # untap them. `homebrew/cask` is required by the casks below; `homebrew/bundle`
    # is required by `brew bundle` itself. Without these entries, cleanup emits
    # `Error: Refusing to untap homebrew/cask because it contains ... `
    # on every activation.
    taps = [
      "homebrew/bundle"
      "homebrew/cask"
    ];

    casks = [
      "docker-desktop"
      "google-chrome"
      "firefox"
      "vlc"
      "spotify"
      "karabiner-elements"
      "claude"
      "claude-code"
      "opencode-desktop"
      "chatgpt"
      "pgadmin4"
      "nordvpn"
      "slack"
      "microsoft-teams"
      "microsoft-powerpoint"
      "microsoft-word"
      "microsoft-excel"
      "zoom"
      "handy"
      "bitwarden"
      "linear"
      "loom"
      "ollama-app"
      "steam"
      "raycast"
      #"flameshot" MacOS Gatekeeper fails
      "discord"
      "audacity"
      "redis-insight"
      "dbeaver-community"
      "1password"
      "prusaslicer"
      "tailscale-app"
      "shottr"
      "google-drive"
      "windows-app"
      "thaw"
      "libreoffice"
      "fathom"
    ];

    brews = [
      "anomalyco/tap/opencode"
    ];
  };
}
