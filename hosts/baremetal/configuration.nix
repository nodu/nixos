# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... } @inputs:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/vpns.nix
      ../../modules/fhs-compat.nix
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

  services = {
    #----- Power Management -----
    logind.settings.Login = {
      # HandlePowerKey = "suspend-then-hibernate";
      # HandleLidSwitch = "suspend-then-hibernate";
      # IdleAction = "suspend-then-hibernate";
      HandlePowerKey = "suspend";
      HandleLidSwitch = "suspend";
      IdleAction = "suspend";
      IdleActionSec = "5min";
    };
    upower.criticalPowerAction = "Hibernate";
    upower.percentageAction = 3;

    #----- Thermal / Fan -----
    lact.enable = true;
  };

  # TODO: re-enable suspend-then-hibernate once s2idle is fixed on kernel 6.19
  # systemd.sleep.extraConfig = ''
  #   HibernateDelaySec=2h
  #   SuspendEstimationSec=1m
  # '';

  virtualisation.docker.enable = true;

  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';

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
  ];
  #wayland requirments/stuff
  security.polkit.enable = true;
  hardware.graphics.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.portal.wlr.enable = true;

  security.pam.services.login.fprintAuth = false;
  # Enable fingerprint auth for GDM login (overrides login's fprintAuth = false,
  # since gdm-password substacks login)
  security.pam.services.gdm-password.fprintAuth = true;

  # Set a shorter timeout for fprintd on i3lock so password auth doesn't wait 60s
  # The PAM stack is serialized, so fprintd must timeout before password auth is tried
  # See: pam_fprintd(8) - timeout option
  security.pam.services.i3lock.rules.auth.fprintd.settings.timeout = 3;
  security.pam.services.i3lock-color.rules.auth.fprintd.settings.timeout = 3;

  # # https://github.com/NixOS/nixpkgs/issues/171136#issuecomment-1627779037
  # # similarly to how other distributions handle the fingerprinting login
  # security.pam.services.gdm-fingerprint = lib.mkIf (config.services.fprintd.enable) {
  #   # lock on suspend not working? no i3 lock mechanism?
  #   text = ''
  #     auth       required                    pam_shells.so
  #     auth       requisite                   pam_nologin.so
  #     auth       requisite                   pam_faillock.so      preauth
  #     auth       required                    ${pkgs.fprintd}/lib/security/pam_fprintd.so
  #     auth       optional                    pam_permit.so
  #     auth       required                    pam_env.so
  #     auth       [success=ok default=1]      ${pkgs.gdm}/lib/security/pam_gdm.so
  #     auth       optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so
  #
  #     account    include                     login
  #
  #     password   required                    pam_deny.so
  #
  #     session    include                     login
  #     session    optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
  #   '';
  # };


  environment.pathsToLink = [ "/libexec" "/share/zsh" ];
  environment.localBinInPath = true;
  environment.variables.GTK_THEME = "Adwaita:dark";

  #maybe set this to false after figuring out users.matt.hashedPassword
  users.mutableUsers = true;


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 20;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable cross-compilation for aarch64 (Raspberry Pi)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking.hostName = "baremetal"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

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
  services.displayManager.gdm.wayland = true;
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

  # Enable CUPS to print documents.
  # services.printing.enable = true;

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

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
  services.libinput.touchpad.clickMethod = "clickfinger";
  services.libinput.touchpad.disableWhileTyping = true;
  services.libinput.mouse.disableWhileTyping = true;

  # Android
  programs.adb.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.matt = {
    isNormalUser = true;
    home = "/home/matt";
    description = "Matt N";
    extraGroups = [ "nordvpn" "docker" "networkmanager" "wheel" "adbusers" "dialout" "input" ];
    openssh.authorizedKeys.keys = [ "ssh blah blah" ];
    shell = pkgs.zsh;

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


  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = [
    pkgs.gnumake
    pkgs.gh
    pkgs.vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    pkgs.wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  fonts = {
    fontDir.enable = true;

    packages = [
      pkgs.nerd-fonts.hack
      pkgs.nerd-fonts.fira-code
    ];
  };


  # List services that you want to enable:

  services.printing.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;
  services.openssh.settings.PermitRootLogin = "no";

  services.fstrim.enable = true;

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
  networking.firewall.checkReversePath = "loose"; #nordvpn + tailscale
  networking.enableIPv6 = true;
  networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];

  # Make hosts writable for nordvpn mesh
  environment.etc.hosts.mode = "0644";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
