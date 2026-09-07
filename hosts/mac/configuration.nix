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

    # Temporary high-resource allocation for kernel builds (rpi3 6.18 bump)
    linux-builder.config = { lib, ... }: {
      virtualisation.cores = lib.mkForce 8;
      virtualisation.memorySize = lib.mkForce 16384;
      # 20 GB is too small for a parallel kernel build (toolchain + objects)
      virtualisation.diskSize = lib.mkForce 40960;
      # GCC on 8 cores can exceed 16 GB RAM when linking
      virtualisation.msize = lib.mkForce 16384;
    };
  };

  # Don't run the linux-builder VM persistently -- it's only needed for ad-hoc
  # rpi3/bau builds. The Makefile targets start/stop it on demand.
  launchd.daemons.linux-builder.serviceConfig = {
    KeepAlive = lib.mkForce false;
    RunAtLoad = lib.mkForce false;
  };

  # Ollama here is the `ollama-app` cask (see homebrew.casks below), started by
  # the GUI rather than a shell, so `environment.variables` never reaches it --
  # launchd's user session is the only channel a menu-bar app inherits from.
  #
  # Pinning the context is not a tuning preference, it avoids a hard failure.
  # Ollama >= 0.33 sizes its default context from reported VRAM instead of the
  # old flat 4096: on this 64 GB M5 Pro it sees 51.8 GiB "available" Metal
  # memory and picks a model's full 262144-token window, which costs ~17 GB of
  # KV cache on a 27B. It then validates that ~36 GB projection against the
  # Metal budget rather than free system RAM, so with ~22 GB actually free it
  # commits anyway and the backend OOMs mid-decode:
  #   error: Insufficient Memory (kIOGPUCommandBufferCallbackErrorOutOfMemory)
  #   ggml_metal_graph_compute: backend is in error state from a previous
  #                             command buffer failure - recreate to recover
  # ggml never recreates the backend, so once wedged *every* model returns an
  # empty 200 response until the server is restarted -- it does not degrade,
  # it silently stops working. 32k holds KV cache near 2 GB.
  #
  # This is a floor for whatever asks first, not a per-model setting. It has to
  # stay conservative because it applies before the engine is known, and the
  # two engines differ: ggml pre-allocates the whole window at load (hence the
  # OOM above), while MLX allocates lazily, so num_ctx is only a ceiling there.
  # Clients that know the model override it per request -- opencode gets
  # 131072 for MLX models from nx-opencode-ollama-sync, measured safe here on a
  # real 227k-token prompt. Anything that does *not* override lands on 32k,
  # which is the point.
  launchd.user.envVariables = {
    OLLAMA_CONTEXT_LENGTH = "32768";
    OLLAMA_MAX_LOADED_MODELS = "1";
    OLLAMA_KEEP_ALIVE = "30m";
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
    onActivation =
      {
        cleanup = "uninstall";
        upgrade = true;
        # Pass --force to `brew bundle` so cleanup runs non-interactively during
        # `make mac/switch` (otherwise Homebrew prompts `Do you want to proceed
        # with the cleanup? [y/n]`).
        extraFlags = [ "--force" ];
      };

    # Declare the baseline Homebrew taps so cleanup does not try (and fail) to
    # untap them. `homebrew/cask` is required by the casks below. Without this
    # entry, cleanup emits `Error: Refusing to untap homebrew/cask because it
    # contains ... ` on every activation. (`homebrew/bundle` is no longer a tap —
    # `brew bundle` is built into Homebrew 6.x — so it must NOT be listed here,
    # or activation would try to re-tap the archived, incompatible repo.)
    taps = [
      "homebrew/cask"
      "stablyai/orca"
    ];

    casks = [
      "uhk-agent"
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
      "codex"
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
      "t3-code"
      "stablyai/orca/orca"
    ];

    brews = [
      "anomalyco/tap/opencode"
    ];
  };
}
