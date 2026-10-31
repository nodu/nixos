# macOS (nix-darwin) system configuration
{ config, pkgs, lib, unstable, ... }:

let
  user = "matt";

  # Shared with home/shared/ssh.nix so the two cannot drift apart.
  meshPeers = import ../../modules/mesh-peers.nix;

  # Only the bare labels go in /etc/hosts. The ".nord" FQDNs are left to Meshnet
  # DNS on purpose: those already resolve in every mode, and leaving them dynamic
  # means a re-registered peer self-heals there instead of silently serving a
  # stale address from a file.
  meshHostsBlock = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: addr: "${addr}\t${name}") meshPeers);
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

  # Local models are served by Unsloth Studio (the `unsloth` cask below) on
  # http://127.0.0.1:8888/v1. Its settings live in the app, not here: Settings >
  # API > "Keyless API access" = full and "Model auto-switch" on, which is what
  # lets opencode (home/scripts/opencode-models.py) and other local clients
  # reach it without a key and load models by name.

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

  #----- Networking -----
  # Make Meshnet peers resolvable by bare hostname system-wide.
  #
  # Meshnet alone resolves bare peer names fine. But when NordVPN is *also*
  # connected to a VPN server, that server's resolver becomes primary: it answers
  # "<name>.nord" and NXDOMAINs the bare label. A DNS search domain can't paper
  # over this, because macOS builds its search list from the primary service --
  # setting one on Wi-Fi only ever applies to en0-scoped queries. /etc/hosts is
  # the one lookup path that wins regardless of which resolver is primary, so it
  # keeps bare names working for ssh and every other client, VPN up or down.
  #
  # This runs in postActivation rather than via environment.etc because
  # nix-darwin's own `networking` activation restores /etc/hosts from
  # /etc/hosts.before-nix-darwin, and postActivation is sequenced after it.
  # The awk pass makes this idempotent and leaves anything outside the markers
  # (including Apple's stock entries) untouched.
  system.activationScripts.postActivation.text = ''
        echo "syncing Meshnet peers into /etc/hosts..." >&2
        meshHostsTmp=$(mktemp)
        ${pkgs.gawk}/bin/awk '
          /^# BEGIN meshnet peers \(nix-darwin\)$/ { skip = 1 }
          !skip                                    { print }
          /^# END meshnet peers \(nix-darwin\)$/   { skip = 0 }
        ' /etc/hosts > "$meshHostsTmp"
        cat >> "$meshHostsTmp" <<'MESHEOF'
    # BEGIN meshnet peers (nix-darwin)
    ${meshHostsBlock}
    # END meshnet peers (nix-darwin)
    MESHEOF
        cat "$meshHostsTmp" > /etc/hosts
        rm -f "$meshHostsTmp"
  '';

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
    onActivation = {
      cleanup = "uninstall";
      upgrade = true;
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
      "unsloth"
      "android-platform-tools"
      "stablyai/orca/orca"
    ];

    brews = [
      "anomalyco/tap/opencode"
      "scrcpy"
    ];
  };
}
