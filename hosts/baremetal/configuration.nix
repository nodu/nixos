# Framework 13 AMD. Shared desktop/server config lives in
# ../../modules/workstation.nix; this file holds what is specific to this
# laptop: lid and battery handling, fingerprint auth, and the network layout.

{ config, pkgs, lib, ... } @inputs:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/workstation.nix
    ];

  services = {
    #----- Power Management -----
    logind.settings.Login = {
      HandlePowerKey = "suspend";
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };

    upower.criticalPowerAction = "Hibernate";
    upower.percentageAction = 3;

    #----- Thermal / Fan -----
    lact.enable = true;
  };

  systemd.services.framework-charge-limit = {
    description = "Cap battery charge at 80% (host is permanently on AC)";
    wantedBy = [ "multi-user.target" "post-resume.target" ];
    after = [ "post-resume.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.framework-tool}/bin/framework_tool --charge-limit 80";
    };
  };

  boot.kernel.sysctl = {
    # Wired and wifi share 192.168.0.0/24. By default wifi also answers ARP for
    # the wired IP, so LAN traffic to it arrives on wlp1s0 and the wired-only
    # firewall rules drop it. Answer ARP only on the NIC that owns the address.
    "net.ipv4.conf.all.arp_ignore" = 1;
    "net.ipv4.conf.all.arp_announce" = 2;
  };

  # TODO: re-enable suspend-then-hibernate once s2idle is fixed on kernel 6.19
  # systemd.sleep.extraConfig = ''
  #   HibernateDelaySec=2h
  #   SuspendEstimationSec=1m
  # '';

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

  # Enable cross-compilation for aarch64 (Raspberry Pi)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking.hostName = "baremetal"; # Define your hostname.

  networking.networkmanager.wifi.powersave = false;

  # Wired LAN only (USB NIC, never wifi): 3773 T3 Code, 3389 xrdp, 2586 homebase ntfy.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i enp193s0f3u2 -p tcp --dport 3773 -s 192.168.0.0/24 -j nixos-fw-accept
    iptables -A nixos-fw -i enp193s0f3u2 -p tcp --dport 3389 -s 192.168.0.0/24 -j nixos-fw-accept
    iptables -A nixos-fw -i enp193s0f3u2 -p tcp --dport 2586 -s 192.168.0.0/24 -j nixos-fw-accept
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
