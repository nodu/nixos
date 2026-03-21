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
  gcloud = pkgs.google-cloud-sdk.withExtraComponents [
    pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
  ];
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
    ./shared/gpg.nix
    ./shared/alacritty.nix
    ./shared/tmux.nix
    ./shared/ssh.nix
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
    unstable.ladybird
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
    pkgs.yt-dlp
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
    pkgs.kubectl
    # pkgs.krew
    # pkgs.terraform
    # pkgs.vault
    # pkgs.awscli2
    # pkgs.azure-cli
    # pkgs.krew
    # pkgs.beekeeper-studio

    unstable.claude-code
    opencode-packages.opencode
    openCodeDesktop
    gcloud
    pkgs.go
    pkgs.python3
    pkgs.nodejs_22
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

  programs = {
    ghostty.enable = true;
  };

  programs.defaults = {
    enable = true;
    basic.enable = true;
    git.enable = true;
    network.enable = true;
  };

  # Override pinentry to GTK for desktop environment
  services.gpg-agent.pinentry.package = lib.mkForce pkgs.pinentry-gtk2;

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
