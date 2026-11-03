# Shared system config for the always-on x86_64 workstations (baremetal, base):
# i3/GNOME desktop, user account, nix settings, remote access, and the
# never-suspend-on-idle power policy. Hardware- and host-specific settings stay
# in each host's configuration.nix.

{ config, pkgs, lib, ... }:

{
  imports = [
    ./vpns.nix
    ./fhs-compat.nix
  ];

  services = {
    nordvpn.enable = true;

    fwupd.enable = true;

    avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        hinfo = true;
        userServices = true;
        workstation = true;
      };
    };

    tailscale.enable = true;
    tailscale.useRoutingFeatures = "client";
  };

  # Keep tailscale installed but don't start at boot (conflicts with NordVPN Meshnet).
  # Use `vpn-switch tailscale` to start on demand.
  systemd.services.tailscaled.wantedBy = lib.mkForce [ ];

  #----- Power Management -----
  # These hosts run as always-on servers: nothing suspends them automatically.
  # Hosts add their own lid/power-button handling on top.
  services.logind.settings.Login = {
    HandlePowerKeyLongPress = "poweroff";
    IdleAction = "ignore";
  };

  services.displayManager.gdm.autoSuspend = false;

  boot.kernel.sysctl = {
    "kernel.panic" = 30;
    "kernel.panic_on_oops" = 1;
  };

  systemd.settings.Manager = {
    RuntimeWatchdogSec = "60s";
    RebootWatchdogSec = "10min";
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_29;

  nix = {
    package = pkgs.nixVersions.latest;

    # No keep-outputs/keep-derivations: generations only need their runtime
    # closures to be switched back to. Keeping every build input of every
    # generation grew baremetal's store to 459G for a 39G system.

    # Automatic Cleanup
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 30d";

    };
    # Auto ooptimise on system rebuild
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      # GC during builds once free space drops below 20G, until 60G is free,
      # instead of waiting for the daily timer to notice a full disk
      min-free = 20 * 1024 * 1024 * 1024;
      max-free = 60 * 1024 * 1024 * 1024;
      # Use all available CPU resources for builds
      max-jobs = "auto";
      cores = 0;
      # Pre-built binaries for nix-community packages (neovim-nightly, etc.)
      substituters = [
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  #wayland requirments/stuff
  security.polkit.enable = true;
  hardware.graphics.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.portal.wlr.enable = true;

  environment.pathsToLink = [ "/libexec" "/share/zsh" ];
  environment.localBinInPath = true;
  environment.variables.GTK_THEME = "Adwaita:dark";

  #maybe set this to false after figuring out users.matt.hashedPassword
  users.mutableUsers = true;


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 20;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable networking
  networking.networkmanager.enable = true;

  # 0 = retry forever. The default of 4 ran out on 2026-09-24 and NM blocked
  # the wifi profile, taking baremetal offline for ten days until a reboot.
  networking.networkmanager.settings = {
    connection."connection.autoconnect-retries" = 0;
  };

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";
  # TODO: Switch to automatic-timezoned once nixpkgs#478774 is fixed
  # (GeoClue shuts down after 60s inactivity, crashing automatic-timezoned)
  # services.automatic-timezoned.enable = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.blueman.enable = true;

  hardware.keyboard.uhk.enable = true;

  environment.gnome.excludePackages = (with pkgs; [
    epiphany # web browser
    gnome-tour
    geary
    gnome-calendar
    gnome-console # use alacritty instead via nautilus-open-any-terminal
  ]) ++ (with pkgs.gnome; [
  ]);

  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "alacritty";
  };
  console.useXkbConfig = true;
  services.xserver = {
    # Configure keymap in X11
    xkb.layout = "us";
    xkb.variant = "";
    xkb.options = "ctrl:nocaps";

    # Enable the X11 windowing system.
    enable = true;

    windowManager.i3.enable = true;

  };

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  # Disable heavy GNOME background services not needed for i3 workflow
  services.gnome.gnome-online-accounts.enable = false;

  # services.displayManager.defaultSession = "sway";
  services.displayManager.defaultSession = "none+i3";

  # Run app images via appimage-run
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    # package = null;
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
  services.libinput.touchpad.clickMethod = "clickfinger";
  services.libinput.touchpad.disableWhileTyping = true;
  services.libinput.mouse.disableWhileTyping = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.matt = {
    isNormalUser = true;
    home = "/home/matt";
    description = "Matt N";
    extraGroups = [ "nordvpn" "docker" "networkmanager" "wheel" "dialout" "input" ];
    openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsX9th55Gnh54WPClEHrylw7Uw7Uu4MfF2lR2Ugi6Jfk2p0/nSdc0eGea8+hulccGgP7UxsZdOnA83ugZ7K+6SdDbc7qdTOst/amfGPYZoJVrAbDhRwfV9JBytjru+MADHPGCp2VBP+5/ko83SWreZZWIhRQypOMCbtvLCLByEk6HxVO19v5RrsQcals19tcwYn9tyCYHYcJxgbY3Y0sH3CrDXLMcy447Yeix7ljTpDDvAV+bW6cyBqUMC1upJ7jNPE4e/r5RudlEytr4JPAGQQPrxLPoBojvz1QE3qOtHdEy151Cz765WdZj23mKNnReWMV4eNm7XWGmQPsvEkWmAeCbYBw6PYNBvMrQSh45+TtJFPC3M+IXdHZhX4GxIPDKp1V0ohG56awp94WTqVvwOaiEO4S8fkVbv/zVzqWfawDKc7p1nFtc1A7Dn8LOxmMUEPn2FkoQjBNoWAxkb5Pch8jV2vRcGrkNP5A5++y/m0AcMR9eomeSn1JLKINGrDIM= matt@nixos" ];
    shell = pkgs.zsh;

    # Start systemd user units at boot without an interactive login, so a
    # reboot brings services back with nobody at the keyboard.
    linger = true;

    packages = with pkgs; [

    ];
  };
  programs.zsh.enable = true;

  programs.steam.enable = true;

  programs.npm = {
    enable = true;
    npmrc =
      ''
        prefix = ''${HOME}/.npm/global
      '';
  };

  # Magnitude (pkgs.magnitude) needs the root-owned, read-only lock its .deb
  # postinst creates, and `magnitude app open` execs /usr/bin/magnitude-desktop.
  systemd.tmpfiles.rules = [
    "d /var/lib/magnitude-desktop 0755 root root -"
    "f /var/lib/magnitude-desktop/installation.lock 0444 root root -"
    "L+ /usr/bin/magnitude-desktop - - - - ${pkgs.magnitude}/bin/magnitude-desktop"
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = [
    pkgs.android-tools # adb; systemd 258 uaccess replaces programs.adb + adbusers
    pkgs.gnumake
    pkgs.gh
    pkgs.smartmontools # smartctl, for checking a drive smartd warned about
    pkgs.vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    pkgs.wget
  ];

  fonts = {
    fontDir.enable = true;

    packages = [
      pkgs.nerd-fonts.hack
      pkgs.nerd-fonts.fira-code
    ];
  };

  services.printing.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;
  services.openssh.settings.PermitRootLogin = "no";

  # Remote desktop. xrdp spawns its own i3 session on connect, separate from the
  # physical one. Open to the wired LAN only (each host's firewall
  # extraCommands); elsewhere, use an SSH tunnel (`ssh baremetal-tunnel`
  # forwards localhost:3389).
  services.xrdp = {
    enable = true;
    defaultWindowManager = "i3";
    openFirewall = false;
  };
  # nixpkgs builds xrdp without H.264, so clients fall back to slow RFX/bitmaps.
  # Overlay rather than services.xrdp.package: the module's ExecStart hardcodes
  # pkgs.xrdp.
  nixpkgs.overlays = [
    (final: prev: {
      xrdp = prev.xrdp.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ prev.x264 ];
        configureFlags = old.configureFlags ++ [ "--enable-x264" ];
      });
    })
  ];

  services.fstrim.enable = true;

  #----- Drive health -----
  # smartd watches every drive it can find (NVMe, SATA, and USB bridges that
  # pass SMART through) and warns on failing health, new bad sectors, failed
  # self-tests, and temperature. Warnings go to the desktop through dunst
  # (systembus-notify) and to every terminal (wall); smartd also logs to the
  # journal (`journalctl -u smartd`). No mail: there is no MTA here.
  # TODO: push smartd warnings to the phone via the homebase ntfy server
  # (baremetal :2586); these hosts are usually unattended, so a popup is easy
  # to miss. Needs a custom -M exec script, since the module allows only one.
  services.smartd = {
    enable = true;
    notifications = {
      systembus-notify.enable = true;
      wall.enable = true;
      # The default xmessage popup targets :0, which needn't be the i3
      # session's display; dunst covers the desktop instead.
      x11.enable = false;
    };
    # -a: all health/attribute/error-log checks. -o/-S: offline data
    # collection and attribute autosave on. -n standby,q: don't spin up a
    # sleeping disk just to poll it. -s: short self-test daily at 02:00, long
    # self-test Sundays at 04:00. -W 4,50,60: log a 4°C jump, log at 50°C,
    # warn at 60°C.
    defaults.monitored = "-a -o on -S on -n standby,q -s (S/../.././02|L/../../7/04) -W 4,50,60";
  };

  # Open ports in the firewall.
  networking.firewall =
    {
      enable = true;
      allowedTCPPorts = [ 443 1701 9001 56150 ]; #443 nordvpn, 1701/9001 weylus, 56150 m365agentsplayground
      allowedUDPPorts = [ 1194 41641 ]; #1194 nordvpn, 41641 tailscale

      allowedUDPPortRanges = [
        { from = 1714; to = 1764; } #kdeconnect
      ];
      allowedTCPPortRanges = [
        { from = 1714; to = 1764; } #kdeconnect
      ];

    };
  # T3 Code (home-manager user service) listens on 0.0.0.0:3773. 3773 and 2586
  # homebase ntfy are reachable over Meshnet and from the home LAN via each
  # host's wired NIC (extraCommands in the host config); 8787 homebase receiver
  # is Meshnet only.
  networking.firewall.interfaces.nordlynx.allowedTCPPorts = [ 3773 8787 2586 ];

  networking.firewall.checkReversePath = "loose"; #nordvpn + tailscale
  networking.enableIPv6 = true;
  networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];

  # Make hosts writable for nordvpn mesh
  environment.etc.hosts.mode = "0644";
}
