# Raspberry Pi 4

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/vpns.nix
  ];

  nix = {
    package = pkgs.nixVersions.latest;

    # Automatic Cleanup
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };

    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "root" "matt" ];
      # Pre-built binaries for nix-community packages (neovim-nightly, etc.)
      substituters = [
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  # Compressed RAM swap -- 8 GB RAM, no disk swap needed
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  environment.pathsToLink = [ "/share/zsh" ];
  environment.localBinInPath = true;

  users.mutableUsers = true;

  networking.hostName = "bau";
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # TODO: Don't forget to set a password with 'passwd'.
  users.users.matt = {
    isNormalUser = true;
    home = "/home/matt";
    description = "Matt N";
    extraGroups = [ "nordvpn" "docker" "networkmanager" "wheel" "dialout" "video" ];
    openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsX9th55Gnh54WPClEHrylw7Uw7Uu4MfF2lR2Ugi6Jfk2p0/nSdc0eGea8+hulccGgP7UxsZdOnA83ugZ7K+6SdDbc7qdTOst/amfGPYZoJVrAbDhRwfV9JBytjru+MADHPGCp2VBP+5/ko83SWreZZWIhRQypOMCbtvLCLByEk6HxVO19v5RrsQcals19tcwYn9tyCYHYcJxgbY3Y0sH3CrDXLMcy447Yeix7ljTpDDvAV+bW6cyBqUMC1upJ7jNPE4e/r5RudlEytr4JPAGQQPrxLPoBojvz1QE3qOtHdEy151Cz765WdZj23mKNnReWMV4eNm7XWGmQPsvEkWmAeCbYBw6PYNBvMrQSh45+TtJFPC3M+IXdHZhX4GxIPDKp1V0ohG56awp94WTqVvwOaiEO4S8fkVbv/zVzqWfawDKc7p1nFtc1A7Dn8LOxmMUEPn2FkoQjBNoWAxkb5Pch8jV2vRcGrkNP5A5++y/m0AcMR9eomeSn1JLKINGrDIM= matt@nixos" ];
    initialPassword = "changeme";
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [
    pkgs.git
    pkgs.gnumake
    pkgs.vim
    pkgs.wget
  ];

  #----- Docker -----
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  #----- NordVPN -----
  services.nordvpn.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # mDNS/service discovery (used by Docker services)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  #----- Bluetooth -----
  hardware.bluetooth.enable = true;
  hardware.raspberry-pi."4".bluetooth.enable = true;

  #----- GPU (RPi4 VideoCore VI) -----
  hardware.graphics.enable = true;

  # The sd-image module enables hardware.enableAllHardware which injects
  # Rockchip/Allwinner/generic kernel modules into the initrd. The RPi4
  # kernel doesn't have these (dw-hdmi, rockchipdrm, etc.), causing build
  # failures. The RPi4 nixos-hardware module already provides the correct
  # initrd modules.
  hardware.enableAllHardware = lib.mkForce false;

  # Disable WiFi (wired-only host)
  # boot.blacklistedKernelModules = [ "brcmfmac" "brcmutil" ];

  # TODO: GPIO fan on pin 14 @ 60°C -- the original Debian config used
  # dtoverlay=gpio-fan,gpiopin=14,temp=60000 in config.txt.
  # After first boot, add the overlay via hardware.deviceTree.overlays or
  # a config.txt snippet once the kernel dtbo path is confirmed.

  #----- Firewall -----
  networking.firewall = {
    enable = true;
    checkReversePath = false; # required for NordVPN
    allowedTCPPorts = [
      22 # SSH
      80 # HTTP (reverse proxy)
      443 # HTTPS (reverse proxy) + NordVPN
      # 1234 # misc service
      # 5432 # PostgreSQL
      # 5800 # VNC / noVNC
      # 8081 # web app
      # 8082 # web app
      # 9999 # misc service
      # 32768 # misc service
    ];
    allowedUDPPorts = [
      # 1194 # NordVPN
      # 1900 # SSDP / UPnP (Jellyfin DLNA)
      # 7359 # Jellyfin client discovery
    ];
  };

  # Make hosts writable for nordvpn mesh
  environment.etc.hosts.mode = "0644";

  system.stateVersion = "25.11";
}
