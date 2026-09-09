# Order 5
{ inputs, ... }:
{ config, lib, pkgs, unstable, handy, opencode-packages, ... }:
# https://mipmip.github.io/home-manager-option-search

let
  # Note: Nix Search for package, click on platform to find binary build status
  # Get specific versions of packages here:
  #   https://lazamar.co.uk/nix-versions/
  # To get the sha256 hash:
  #   nix-prefetch-url --unpack https://github.com/NixOS/nixpkgs/archive/<commit>.tar.gz
  #   or use an empty sha256 = ""; string, it'll show the hash; prefetch is safer
  # Disable GPU hardware acceleration to fix grey screen/freeze on amdgpu
  # Supply gst-plugins-good so WebKit's GStreamer backend can create an audio
  # sink (autoaudiosink/pulsesink). Without it, WebKitWebProcess crashes with
  # SIGABRT in MediaPlayerPrivateGStreamer::createAudioSink().
  openCodeDesktop = pkgs.writeShellScriptBin "opencode-desktop" ''
    export GST_PLUGIN_SYSTEM_PATH_1_0="${unstable.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0:${unstable.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0''${GST_PLUGIN_SYSTEM_PATH_1_0:+:$GST_PLUGIN_SYSTEM_PATH_1_0}"
    exec ${unstable.opencode-desktop}/bin/OpenCode --disable-gpu --use-gl=angle --use-angle=swiftshader "$@"
  '';

  freerdpLauncherGPC =
    pkgs.writeShellApplication
      {
        name = "freerdp3-launcher-GPC.sh";
        runtimeInputs = [ pkgs.zenity pkgs.freerdp ];
        text = ''
          pw=$(gpg --decrypt "$HOME"/.secrets/gpc-rdp-secret.gpg)
          # pw=$(zenity --entry --title="Domain Password" --text="Enter your _password:" --hide-text)
          xfreerdp /v:192.168.0.3 +clipboard /dynamic-resolution /sound:sys:alsa /u:GPC /d: /p:"$pw"
        '';
      };

  vpnSwitch = pkgs.writeShellScriptBin "vpn-switch" ''
    set -euo pipefail

    DEFAULT_EXIT_NODE="tailscale-subnet-router"
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color

    usage() {
      echo "Usage: vpn-switch <tailscale|nordvpn|off|status>"
      echo ""
      echo "Commands:"
      echo "  tailscale  Disconnect NordVPN tunnel, start Tailscale exit node"
      echo "  nordvpn    Stop Tailscale service (connect NordVPN manually)"
      echo "  off        Disconnect NordVPN tunnel, stop Tailscale service"
      echo "  status     Show status of both VPNs"
      exit 1
    }

    nord_disconnect() {
      echo -e "''${YELLOW}Disconnecting NordVPN tunnel...''${NC}"
      nordvpn disconnect 2>/dev/null | grep -v "You are not connected" || true
      # NordVPN often leaves DNS in a broken state after disconnect.
      # Reload NetworkManager to restore DNS resolution.
      sleep 1
      echo -e "''${YELLOW}Restoring DNS...''${NC}"
      sudo nmcli general reload dns-full
    }

    tailscale_start() {
      echo -e "''${YELLOW}Starting tailscaled service...''${NC}"
      sudo systemctl start tailscaled

      # Wait for the daemon socket to be ready
      local retries=0
      while [ $retries -lt 10 ]; do
        if tailscale status &>/dev/null; then
          break
        fi
        sleep 0.5
        retries=$((retries + 1))
      done

      echo -e "''${YELLOW}Connecting to Tailscale network...''${NC}"
      sudo tailscale up --reset --accept-routes

      echo -e "''${GREEN}Setting exit node: $DEFAULT_EXIT_NODE''${NC}"
      sudo tailscale set --exit-node="$DEFAULT_EXIT_NODE" --exit-node-allow-lan-access
    }

    tailscale_stop() {
      if systemctl is-active --quiet tailscaled; then
        echo -e "''${YELLOW}Stopping tailscaled service...''${NC}"
        sudo systemctl stop tailscaled
      else
        echo -e "''${BLUE}Tailscale service already stopped''${NC}"
      fi
    }

    show_status() {
      echo -e "''${BLUE}--- NordVPN ---''${NC}"
      nordvpn status 2>/dev/null || echo "nordvpn daemon not running"
      echo ""
      echo -e "''${BLUE}--- Tailscale ---''${NC}"
      if systemctl is-active --quiet tailscaled; then
        tailscale status 2>/dev/null || echo "tailscaled running but not connected"
      else
        echo "tailscaled service stopped"
      fi
    }

    if [ $# -lt 1 ]; then
      usage
    fi

    case "$1" in
      tailscale|ts)
        nord_disconnect
        tailscale_start
        echo -e "''${GREEN}Switched to Tailscale exit node''${NC}"
        ;;
      nordvpn|nord)
        tailscale_stop
        echo -e "''${GREEN}Switched to NordVPN mode (Meshnet active)''${NC}"
        echo "Connect manually: nordvpn connect <server>"
        ;;
      off)
        nord_disconnect
        tailscale_stop
        echo -e "''${GREEN}All VPN tunnels disconnected (Meshnet still active)''${NC}"
        ;;
      status)
        show_status
        ;;
      *)
        usage
        ;;
    esac
  '';
in
{
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.defaults.homeManagerModules.default
    (import ./shared/neovim.nix { inherit inputs; })
    ./shared/shell.nix
    ./shared/git.nix
    ./shared/cli.nix
    ./shared/devops.nix
    ./shared/gpg.nix
    ./shared/alacritty.nix
    ./shared/ghostty.nix
    ./shared/tmux.nix
    ./shared/ssh.nix
    ./shared/claude.nix
    ./shared/opencode.nix
    ./sway/sway.nix
    ./i3/i3.nix
    # ./hyprland/hyprland.nix
  ];

  # https://tinted-theming.github.io/base16-gallery
  # colorScheme = inputs.nix-colors.colorSchemes.onedark;
  colorScheme = inputs.nix-colors.colorSchemes.catppuccin-mocha;


  #cat "$1" | col -bx | bat --language man --style plain

  # Home-manager 22.11 requires this be set. We never set it so we have
  # to use the old state version.
  home.stateVersion = "23.05";

  xdg.enable = true;

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------

  home.packages = [
    # freerdp3GPClauncher Add the shell application here if wanted in path
    # To pin a specific package version, import a specific nixpkgs commit:
    # let oldPkgs = import (builtins.fetchTarball {
    #   url = "https://github.com/NixOS/nixpkgs/archive/<commit-hash>.tar.gz";
    #   sha256 = "<hash>";
    # }) { inherit (pkgs) system; config.allowUnfree = true; };
    # in [ oldPkgs.chromium ]
    # See https://www.nixhub.io to find commits for specific versions

    # GUI Apps
    pkgs.google-chrome
    pkgs.firefox
    #unstable.ladybird
    pkgs.obs-studio
    pkgs.vlc
    pkgs.jellyfin-media-player
    # pkgs.kodi
    pkgs.spotify
    pkgs.discord
    pkgs.anki-bin
    #pkgs.baobab
    pkgs.zoom-us
    # unstable.vscode
    pkgs.scrcpy
    unstable.uhk-agent
    pkgs.prusa-slicer
    pkgs.bitwarden-desktop
    unstable.godot
    pkgs.freerdp
    pkgs.remmina
    pkgs.kdePackages.okular # PDF
    pkgs.blender
    # unstable.rpi-imager
    pkgs.arandr
    pkgs.sunsama
    handy

    pkgs.zenity

    # Sound
    pkgs.helvum
    pkgs.qpwgraph
    pkgs.pwvucontrol
    pkgs.coppwr
    pkgs.audacity

    # Baremetal-specific utilities
    pkgs.kdePackages.kdeconnect-kde
    pkgs.normcap
    pkgs.xdotool
    # Check Bios version:
    # sudo dmidecode | grep -A3 'Vendor:\|Product:' && sudo lshw -C cpu | grep -A3 'product:\|vendor:'
    pkgs.dmidecode

    # GPU
    pkgs.gamemode
    pkgs.amdgpu_top
    pkgs.lact
    pkgs.corectrl

    # Gnome
    pkgs.gnome-tweaks
    pkgs.atomix
    pkgs.gnome-sudoku
    pkgs.iagno
    pkgs.gnomeExtensions.power-profile-switcher
    pkgs.gnomeExtensions.grand-theft-focus
    pkgs.gnomeExtensions.gnordvpn-local
    pkgs.gnomeExtensions.nordvpn-quick-toggle
    pkgs.dconf-editor

    # Network
    pkgs.inetutils
    pkgs.wget
    pkgs.speedtest-cli
    pkgs.httpstat
    pkgs.sshfs
    pkgs.nmap
    #pkgs.tshark
    vpnSwitch

    # pkgs.postgresql_11
    # pkgs.krew
    # pkgs.terraform
    # pkgs.vault
    # pkgs.awscli2
    # pkgs.azure-cli
    # pkgs.krew
    # pkgs.beekeeper-studio

    unstable.claude-code
    unstable.t3code
    unstable.codex
    opencode-packages.opencode
    openCodeDesktop
    pkgs.go
    pkgs.yarn
    pkgs.cargo

    # Note: need to set credsStore
    # ".docker/config.json".text = builtins.toJSON {
    #   credsStore = "secretservice";
    # };
    pkgs.docker-credential-helpers

    # Baremetal-only CLI tools
    pkgs.gcc
    pkgs.ffmpeg

    # Baremetal-only LSPs and linters
    pkgs.statix
    # pkgs.marksman  # TODO: Re-enable when dotnet build issue is fixed (nixpkgs#XXXXX)
    pkgs.lua-language-server
    pkgs.vtsls
    pkgs.nodePackages.vscode-langservers-extracted
    pkgs.nodePackages.typescript-language-server
    pkgs.pyright
    pkgs.dockerfile-language-server
    pkgs.tailwindcss-language-server
    # TODO: Update to stable
    unstable.ruff
    # TODO: not quite working:
    pkgs.docker-compose-language-service
    pkgs.stylua
    pkgs.markdownlint-cli2
    pkgs.nodePackages.prettier
  ];

  fonts.fontconfig.enable = true;
  #---------------------------------------------------------------------
  # Env vars and dotfiles
  #---------------------------------------------------------------------
  #home.file.".inputrc".source = ./inputrc;

  # https://github.com/netbrain/zwift
  # docker run -v zwift-$USER:/data --name zwift-copy-op busybox true
  # docker cp .zwift-credentials zwift-copy-op:/data
  # docker rm zwift-copy-op
  home.file = {
    "zwift.sh" = {
      source = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/netbrain/zwift/master/zwift.sh";
        hash = "sha256-joipzHtLvy+l4H+NOLTSpVf8bzVGUF4JVDcyfQIt5II=";
      };
      target = ".local/bin/zwift";
      executable = true;
    };
  };

  xdg.configFile = {
    "rofi" = {
      source = ./rofi;
      recursive = true;
    };
  };

  xdg.desktopEntries =
    {
      btop = {
        type = "Application";
        name = "Activity Monitor (btop)";
        exec = "btop";
        terminal = true;
        categories = [ "Application" "Network" "WebBrowser" ];
        mimeType = [ "text/html" "text/xml" ];
      };
      gotop = {
        type = "Application";
        name = "Activity Monitor (goTop)";
        exec = "gotop";
        terminal = true;
        categories = [ "Application" "Network" "WebBrowser" ];
        mimeType = [ "text/html" "text/xml" ];
      };
      normcap = {
        type = "Application";
        name = "normcap - OCR screenshot";
        exec = "normcap";
        categories = [ "Application" ];
      };
      settings = {
        type = "Application";
        name = "Settings";
        exec = "env XDG_CURRENT_DESKTOP=Gnome gnome-control-center";
        categories = [ "Application" "Settings" ];
      };
      zwift = {
        type = "Application";
        name = "Zwift";
        exec = "/home/matt/.local/bin/zwift";
        categories = [ "Application" "Game" ];
      };
      freeRDPGPC = {
        type = "Application";
        name = "RDP GPC";
        icon = "🖥️";
        terminal = false;
        exec = lib.getExe freerdpLauncherGPC;
        categories = [ "Application" ];
      };
      opencode-desktop = {
        type = "Application";
        name = "OpenCode";
        comment = "The open source AI coding agent";
        exec = "opencode-desktop";
        icon = "${unstable.opencode-desktop}/share/icons/hicolor/128x128/apps/OpenCode.png";
        terminal = false;
        categories = [ "Application" "Development" ];
        mimeType = [ "x-scheme-handler/opencode" ];
      };
      audio-output = {
        type = "Application";
        name = "Audio Output";
        exec = "/home/matt/.config/i3/scripts/audio-output-menu";
        icon = "audio-speakers-symbolic";
        categories = [ "Settings" ];
      };
      audio-input = {
        type = "Application";
        name = "Audio Input";
        exec = "/home/matt/.config/i3/scripts/audio-input-menu";
        icon = "audio-input-microphone-symbolic";
        categories = [ "Settings" ];
      };
      power-profile = {
        type = "Application";
        name = "Power Profile";
        exec = "/home/matt/.config/i3/scripts/power-profiles";
        icon = "power-profile-balanced-symbolic";
        categories = [ "Settings" ];
      };
    };

  #---------------------------------------------------------------------
  # Programs
  #---------------------------------------------------------------------

  programs.defaults = {
    enable = true;
    basic.enable = true;
    git.enable = true;
    network.enable = true;
  };

  # Override pinentry to GTK for desktop environment
  services.gpg-agent.pinentry.package = lib.mkForce pkgs.pinentry-gtk2;

  # models live in ~/.ollama/models

  # CPU inference, deliberately. The Radeon 780M iGPU was tried (ollama-rocm +
  # HSA_OVERRIDE_GFX_VERSION=11.0.0 + OLLAMA_IGPU_ENABLE=1 + HSA_ENABLE_SDMA=0)
  # and rejected. Re-verified 2026-09-08 against ROCm 7.2.3: one of the two
  # original reasons is now stale, the other is not, and a third has appeared.
  #
  # 1. STALE -- 'gfx110x ROCm hard-hangs ("HW Exception ... GPU Hang")'. ROCm
  #    has since made gfx1103 a native build target: nixpkgs-unstable builds
  #    both rocblas and ollama-rocm with gfx1103 in the target list, and the
  #    kernel reports the arch honestly --
  #      /sys/class/kfd/kfd/topology/nodes/1/properties -> gfx_target_version
  #      = 110003
  #    So do NOT restore HSA_OVERRIDE_GFX_VERSION=11.0.0 on a retry. Forcing
  #    the gfx1100 code path onto gfx1103 silicon is the likely cause of those
  #    hangs, and re-setting it would reproduce them and look like proof that
  #    nothing improved. OLLAMA_IGPU_ENABLE=1 is still needed (ollama skips
  #    iGPUs by default); HSA_ENABLE_SDMA=0 was a hang workaround, so retry
  #    without it first.
  #
  # 2. STILL TRUE -- the 780M has no dedicated memory. It reads weights over
  #    the same LPDDR5 bus as the CPU (~100 GB/s on a 7840U) and token
  #    generation is memory-bandwidth bound, so decode cannot beat CPU however
  #    good the driver gets. ROCm support does not add bandwidth. Prefill is
  #    compute-bound and would genuinely speed up -- that, and only that, is
  #    the argument for retrying.
  #
  # 3. NEW BLOCKER -- ROCm sees a single 15.33 GiB heap on this box. KFD
  #    reports the GTT pool as HEAP_TYPE_FB_PUBLIC; the 512M VRAM carveout is
  #    display-side and adds no compute-addressable room, so the two do not
  #    sum. qwen3.8:27b is 15.66 GiB of weights + 0.87 GiB projector before any
  #    KV cache, so it cannot fully offload. Its KV cache is also fat: 65
  #    layers x 4 KV heads x (256+256) x 2 B = 260 KiB/token, i.e. 8.12 GiB at
  #    our 32k context. Full offload would need amdgpu.gttsize (megabytes,
  #    default -1 = auto = half of RAM):
  #      32k / f16 KV  -> 25.1 GiB  gttsize=26624
  #      32k / q8_0 KV -> 21.1 GiB  gttsize=22528
  #      4k  / q8_0 KV -> 17.5 GiB  gttsize=18432   (absolute floor, and 4k is
  #                                                  the truncation trap below)
  #    gttsize is a ceiling on pinnable system RAM rather than a boot-time
  #    carve-out, but once the model loads those pages really are pinned, and
  #    surrendering 22-26 GiB of 30 GiB to win prefill on a bandwidth-bound
  #    decode is a bad trade. Leave it at auto.
  #
  # To retry meaningfully: pull an 8-14B model that fits under 15.33 GiB with
  # its KV cache, set package = unstable.ollama-rocm, leave gttsize alone, and
  # measure time-to-first-token rather than tok/s -- decode is not the win.
  #
  # Context window: pin it explicitly, because the default has been wrong in
  # both directions and neither failure is loud.
  #
  # Ollama <= 0.32 defaulted to OLLAMA_CONTEXT_LENGTH=4096 and silently
  # truncated anything larger (opencode's system prompt + MCP tool schemas + a
  # pasted doc blow past it in one message, and the model ends up blind to its
  # own instructions).
  #
  # Ollama >= 0.33 inverted it: the default is now sized from reported VRAM and
  # will happily take a model's full advertised window -- 262144 tokens on the
  # current qwen3.x builds -- whose KV cache alone can exceed free RAM. On the
  # Mac that OOMs the Metal backend into a state where every model returns an
  # empty response (see hosts/mac/configuration.nix); here it just means
  # allocating far more than a 30 GB box has.
  #
  # 32k is also what nx-opencode-ollama-sync emits for gguf models, which is
  # every model here -- this box runs ggml on CPU, and ggml pre-allocates the
  # whole window at load, so the cap is a real reservation rather than a
  # ceiling. (The sync script raises it for MLX models, which allocate lazily,
  # but those are Apple-Silicon-only and will never appear on this host.) KV
  # cache grows with this, so pin one loaded model at a time to stay inside the
  # 30 GB of RAM alongside a 20-27B model.
  services.ollama = {
    enable = true;
    package = unstable.ollama;
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "32768";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_KEEP_ALIVE = "30m";
    };
  };

  # T3 Code: GUI/control plane over the agent CLIs (claude, codex, opencode),
  # reachable from the Pixel and maemac over NordVPN Meshnet. Meshnet has no
  # equivalent of `tailscale serve`, so this is plain HTTP -- fine for the
  # native mobile and desktop apps, which pair to a bare IP. It rules out
  # app.t3.codes, which is HTTPS-only and cannot call an HTTP backend.
  #
  # Binds 0.0.0.0 rather than the nordlynx IP so the unit still starts when
  # Meshnet is down; exposure is fenced by the interface-scoped firewall rule
  # in hosts/baremetal/configuration.nix, which opens 3773 on nordlynx only.
  #
  # Deliberately NOT named t3code.service: the t3 CLI's own `t3 service`
  # manager claims that exact name, and would collide with this read-only
  # nix-store symlink. Keeping them distinct leaves `t3 service` usable.
  #
  # This owns port 3773. Do not also configure a desktop-managed SSH
  # environment pointing at this host -- that launches a second, competing
  # server on 127.0.0.1:3773 and the two fight over the port.
  #
  # Likewise prefer the browser at http://localhost:3773 over the T3 Code
  # desktop app on this host. The desktop app attaches to this server fine,
  # but on quit it deletes ~/.t3/userdata/server-runtime.json, which it did
  # not create. The server keeps running and already-connected clients stay
  # up, but `t3 pair` discovers the server through that file and starts
  # failing with NoRunningServerError. Fix: restart this unit.
  systemd.user.services.t3code-server = {
    Unit = {
      Description = "T3 Code agent control plane";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      # Give up after 5 failures in 5min rather than restarting forever. Without
      # this, a port conflict just loops silently -- an earlier version of this
      # unit logged 4095 restarts against EADDRINUSE instead of failing loudly.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    Service = {
      Type = "simple";
      ExecStart = "${unstable.t3code}/bin/t3 serve --host 0.0.0.0 --port 3773";
      # t3 resolves provider CLIs by probing the login shell at runtime, so this
      # is a safety net rather than load-bearing.
      Environment = [
        "PATH=/run/wrappers/bin:${config.home.homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/matt/bin:/run/current-system/sw/bin"
        "T3CODE_HOME=${config.home.homeDirectory}/.t3"
      ];
      WorkingDirectory = config.home.homeDirectory;
      # Tear down the whole node process tree; survive the OOM killer taking a
      # child. Both mirror what `t3 service install` generates.
      KillMode = "mixed";
      OOMPolicy = "continue";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Baremetal-specific direnv whitelisted directories
  programs.direnv.config = {
    whitelist = {
      prefix = [
      ];

      exact = [
        "~/repos/job-scraper/"
        "~/repos/10four-ai/"
        "~/repos/www/"
      ];
    };
  };

  # Setup i3 exclusively in HM; remove from configiguration.nix
  # https://github.com/srid/nix-config/blob/705a70c094da53aa50cf560179b973529617eb31/nix/home/i3.nix
  programs.rofi = {
    enable = true;
    #package = unstable.rofi-wayland;
    # theme = "slate";
    plugins = [
      pkgs.rofi-calc
      pkgs.rofi-emoji
    ];

    extraConfig = {
      modes = "combi";
      modi = "combi,emoji,filebrowser,calc,run,window"; #calc,run,filebrowser,
      combi-modes = "window,drun";
      show-icons = true;
      sort = true;
      matching = "fuzzy";
      case-sensitive = false;
      dpi = 220;
      font = "Hack Nerd Font Mono 10";
      terminal = "alacritty";
      sorting-method = "fzf";
      combi-hide-mode-prefix = true;
      drun-display-format = "{icon} {name}";
      disable-history = true;
      click-to-exit = true;
      icon-theme = "Adwaita";
      hide-scrollbar = true;
      sidebar-mode = true;
      display-filebrowser = "📁";
      display-combi = "🔎";
      display-emoji = "😀";
      display-calc = "🧮";
      display-drun = "   Apps ";
      display-run = "🚀";
      display-window = "🪟";
      display-Network = " 󰤨  Network";
      kb-mode-next = "Tab";
      kb-mode-previous = "ISO_Left_Tab"; #Shift+Tab
      kb-element-prev = "";
      kb-element-next = "";
      kb-select-1 = "Alt+1";
      kb-select-2 = "Alt+2";
      kb-select-3 = "Alt+3";
      kb-select-4 = "Alt+4";
      kb-select-5 = "Alt+5";
      kb-select-6 = "Alt+6";
      kb-select-7 = "Alt+7";
      kb-select-8 = "Alt+8";
      kb-select-9 = "Alt+9";
      kb-select-10 = "Alt+0";
      kb-custom-1 = "";
      kb-custom-2 = "";
      kb-custom-3 = "";
      kb-custom-4 = "";
      kb-custom-5 = "";
      kb-custom-6 = "";
      kb-custom-7 = "";
      kb-custom-8 = "";
      kb-custom-9 = "";
      kb-custom-10 = "";
    };
    # "theme" = "./rofi-theme-deathemonic.rasi";
    "theme" = "./catppuccin-mocha.rasi";
  };

  # Baremetal-specific alacritty overrides (shared config in ./shared/alacritty.nix)
  programs.alacritty = {
    package = unstable.alacritty;
    settings.env.WINIT_X11_SCALE_FACTOR = "1"; # https://major.io/p/disable-hidpi-alacritty/ #i3 font size fix
  };

  home.pointerCursor = {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 32;
    x11.enable = true;
    gtk.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
    };
  };
}
