# Raspberry Pi 3 - Minimal headless server configuration

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

  # Compressed RAM swap -- effectively extends 1 GB RAM to ~1.5 GB
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  environment.pathsToLink = [ "/share/zsh" ];
  environment.localBinInPath = true;

  users.mutableUsers = true;

  networking.hostName = "rpi3";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Los_Angeles";

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

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.matt = {
    isNormalUser = true;
    home = "/home/matt";
    description = "Matt N";
    extraGroups = [ "nordvpn" "networkmanager" "wheel" "dialout" ]; #dialout for gaggimate
    openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsX9th55Gnh54WPClEHrylw7Uw7Uu4MfF2lR2Ugi6Jfk2p0/nSdc0eGea8+hulccGgP7UxsZdOnA83ugZ7K+6SdDbc7qdTOst/amfGPYZoJVrAbDhRwfV9JBytjru+MADHPGCp2VBP+5/ko83SWreZZWIhRQypOMCbtvLCLByEk6HxVO19v5RrsQcals19tcwYn9tyCYHYcJxgbY3Y0sH3CrDXLMcy447Yeix7ljTpDDvAV+bW6cyBqUMC1upJ7jNPE4e/r5RudlEytr4JPAGQQPrxLPoBojvz1QE3qOtHdEy151Cz765WdZj23mKNnReWMV4eNm7XWGmQPsvEkWmAeCbYBw6PYNBvMrQSh45+TtJFPC3M+IXdHZhX4GxIPDKp1V0ohG56awp94WTqVvwOaiEO4S8fkVbv/zVzqWfawDKc7p1nFtc1A7Dn8LOxmMUEPn2FkoQjBNoWAxkb5Pch8jV2vRcGrkNP5A5++y/m0AcMR9eomeSn1JLKINGrDIM= matt@nixos" ];
    initialPassword = "changeme";
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [
    pkgs.gnumake
    pkgs.vim
    pkgs.wget
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # gaggimate
  services.udev.extraRules = ''
    # ESP32-S3 USB JTAG/serial (Espressif VID:PID 303a:1001)
    SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", MODE="0666", GROUP="dialout"
    SUBSYSTEM=="usb", ATTR{idVendor}=="303a", ATTR{idProduct}=="1001", MODE="0666", GROUP="dialout"
  '';

  networking.firewall.enable = true;
  networking.firewall.checkReversePath = false; # required for NordVPN
  networking.firewall.allowedTCPPorts = [ 443 ]; # NordVPN
  networking.firewall.allowedUDPPorts = [ 1194 ]; # NordVPN

  # Make hosts writable for nordvpn mesh
  environment.etc.hosts.mode = "0644";

  #----- NordVPN -----
  services.nordvpn.enable = true;

  system.stateVersion = "25.11";
}
