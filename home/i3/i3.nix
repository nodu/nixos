{ pkgs, lib, ... }:
{
  xdg.configFile = {
    "i3/scripts" = {
      source = ./scripts;
      recursive = true;
    };
    "i3/config".text = builtins.readFile ./i3.config;
    "i3/i3blocks.conf".text = builtins.readFile ./i3blocks.conf;
    "i3/notify-sleep.sh" = {
      text = builtins.readFile ./notify-sleep.sh;
      executable = true;
    };

  };

  #Packages
  home.packages = with pkgs;
    [
      pkgs.playerctl
      pkgs.brightnessctl
      pkgs.xss-lock
      pkgs.maim
      pkgs.xdotool
      pkgs.xclip
      pkgs.networkmanagerapplet
      pkgs.dunst
      pkgs.xorg.xhost
      pkgs.feh
      pkgs.i3blocks
      pkgs.i3lock-color
      # needed for i3blocks scripts;
      pkgs.python3
      pkgs.acpi
      pkgs.font-awesome
      pkgs.libnotify
      pkgs.batsignal
    ];

  services.blueman-applet.enable = true;

  programs.i3status = {
    enable = false;

    general = {
      colors = true;
      color_good = "#8C9440";
      color_bad = "#A54242";
      color_degraded = "#DE935F";
      interval = 5;
    };

    modules = {
      ipv6.enable = false;
      "wireless _first_".enable = false;
      "wireless _first_".position = 5;
      "battery all".enable = true;
      "disk /" = {
        position = 1;
        settings = { format = "󰨣 %free (%avail)/ %total"; };
      };
      load = {
        position = 2;
        settings = { format = "󰝲 %1min"; };
      };
      memory = {
        position = 3;
        settings.format = "󰍛 F:%free A:%available (U:%used) / T:%total";
      };
      "ethernet _first_" = {
        enable = false;
        position = 4;
        settings = {
          format_up = "E: %ip"; #
          format_down = "E: down";
        };
      };
      "volume master" = {
        position = 6;
        settings = {
          mixer = "Master";
          format = " %volume";
          format_muted = "♪ muted (%volume)";
          device = "default";
        };
      };
      "tztime local" = {
        position = 7;
        settings = { format = "%Y-%m-%d %H:%M:%S"; };
      };
    };
  };

  services.dunst = {
    enable = true;
    settings = {
      global = {
        follow = "keyboard";
        width = 300;
        height = 300;
        offset = "30x50";
        origin = "top-right";
        transparency = 10;
        frame_color = "#eceff1";
        font = "Hack Nerd Font Mono 14";

      };
      urgency_normal = { background = "#37474f"; foreground = "#eceff1"; timeout = 10; };
    };
  };

  #----- Battery Notifications -----
  systemd.user.services.batsignal = {
    Unit = {
      Description = "Battery level notification daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.batsignal}/bin/batsignal -n BAT1 -w 15 -c 7 -d 4 -e";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  services.picom = {
    enable = true;
    shadow = true;
    shadowOpacity = 0.75;
    shadowExclude = [
      "class_g = 'Handy' && name = 'Recording'"
    ];
    fade = true;
    vSync = true;
    fadeDelta = 5;
    settings = {
      no-fading-openclose = true;
      # unredir-if-possible = false;  # if tearing in fullscreen
    };
    wintypes = {
      dropdown_menu = { opacity = 1.000000; shadow = false; };
      popup_menu = { opacity = 1.000000; shadow = false; };
      utility = { opacity = 1.000000; shadow = false; };
      menu = { opacity = 1.000000; shadow = false; };
    };

  };

  services.redshift = {
    enable = true;
    latitude = 37.77397;
    longitude = -122.431297;
    tray = true;
    temperature = {
      day = 6500;
      night = 3700;
    };
    settings = {
      redshift = {
        brightness-day = "1";
        brightness-night = "0.7";
      };
    };
  };
}
