# Desktop workstation + always-on server: i7-6700K on an ASUS Maximus VIII
# Hero. The CPU's HD 530 drives the host display, firmware screens included,
# so the two RTX 3090s are compute-only (CUDA for Unsloth Studio). ./gtx1080.nix
# adds the GTX 1080 back as a third compute card. Shared desktop/server
# config lives in ../../modules/workstation.nix. Install steps are in
# ./INSTALL.md.

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix # the data pool's disks and datasets; goes with zfs.nix
    ./zfs.nix
    ./restic.nix
    # ./gtx1080.nix # with ../../home/base-gtx1080.nix in home-base.nix
    ../../modules/workstation.nix
  ];

  networking.hostName = "base";

  # The KVM's USB NIC (RTL8153, stuck at USB 2.0 speed) disappears whenever the
  # KVM is switched away, and while present it took the default route from the
  # onboard Intel NIC (.3). Matched by MAC since its name follows the USB port.
  networking.networkmanager.unmanaged = [ "mac:34:1b:22:85:43:c4" ];

  # No swap partition; 32 GB of RAM rarely needs disk swap.
  zramSwap.enable = true;
  # Swapping to zram is far cheaper than dropping page cache, so prefer it,
  # and don't read ahead: there is no seek cost to amortize.
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
  };

  #----- GPUs: iGPU display, NVIDIA compute-only -----
  # The NixOS nvidia module only loads the kernel driver when "nvidia" is in
  # videoDrivers, but that also gives Xorg an nvidia screen. Keep the driver
  # and hand Xorg the iGPU alone.
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.drivers = lib.mkForce [{ name = "modesetting"; display = true; }];
  services.xserver.externallyConfiguredDrivers = [ "nvidia" ];
  hardware.nvidia = {
    # Ampere gets NVIDIA's open kernel module and current driver; ./gtx1080.nix
    # overrides both for Pascal.
    open = lib.mkDefault true;
    package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.production;
    # No KMS: nothing drives a display from these cards, so there is no
    # nvidia framebuffer console and Xorg can't pick them up as extra GPUs.
    modesetting.enable = false;
    nvidiaSettings = false;
    # Keeps idle cards initialised, so they drop to P8 and keep power limits.
    nvidiaPersistenced = true;
  };

  # GDM's Wayland greeter fails to hand the NVIDIA display over to Xorg/i3.
  # GNOME 50 no longer supports an X11 GDM greeter; use LightDM on this host.
  services.displayManager.gdm.enable = lib.mkForce false;
  services.xserver.displayManager.lightdm.enable = true;

  # Keep the desktop off the NVIDIA cards so their VRAM stays free. Xorg is
  # pinned to the iGPU (00:02.0), and
  # AutoAddGPU stops it attaching the other cards as secondary GPUs. The GDM
  # greeter runs on mutter, which skips devices tagged mutter-device-ignore.
  services.xserver.deviceSection = ''
    BusID "PCI:0:2:0"
  '';
  services.xserver.serverFlagsSection = ''
    Option "AutoAddGPU" "false"
  '';
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", ATTRS{vendor}=="0x10de", TAG+="mutter-device-ignore"
  '';
  # The board has one DP 1.2 and one HDMI 1.4 port, and i915 caps HDMI at
  # 300 MHz: 3840x2400 at 30 Hz, 3440x1440 at ~50. Whichever monitor is on DP
  # gets its full rate. So rather than fixed output names and rates, each
  # monitor gets its preferred mode (xrandr lists it first) at the highest
  # rate the port allows. Monitors go left to right, widest mode first; the
  # 3440x1440 is primary. LightDM reuses its X server for the session, so i3
  # gets this too.
  services.xserver.displayManager.setupCommands = ''
    xrandr=${lib.getExe pkgs.xrandr}
    x=0
    while read -r out mode rate; do
      primary=""
      if [ "$mode" = 3440x1440 ]; then primary=--primary; fi
      $xrandr --output "$out" --mode "$mode" --rate "$rate" --pos "''${x}x0" $primary
      x=$((x + ''${mode%x*}))
    done < <($xrandr | ${lib.getExe pkgs.gawk} '
      / connected/ { out = $1; next }
      out && /^ / {
        rate = 0
        for (i = 2; i <= NF; i++) { r = $i; gsub(/[*+]/, "", r); if (r + 0 > rate + 0) rate = r }
        print out, $1, rate
        out = ""
      }' | ${pkgs.coreutils}/bin/sort -k2,2r)
  '';

  # GPUs in docker: `docker run --device nvidia.com/gpu=all ...`
  hardware.nvidia-container-toolkit.enable = true;

  # Strix 3090 GPU-f3039727 falls off the bus (Xid 79) after ~10 min at full
  # power until it is repasted. Cap it.
  systemd.services.rtx3090-power-limit = {
    wantedBy = [ "multi-user.target" ];
    after = [ "nvidia-persistenced.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi -i GPU-f3039727-ff98-e47c-5d66-906f2ea741f2 -pl 270";
    };
  };

  # Prebuilt CUDA-enabled packages; otherwise anything built with CUDA support
  # compiles locally
  nix.settings = {
    substituters = [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };

  #----- Windows VM -----
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true; # TPM 2.0 for Windows 11
  };
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;
  users.users.matt.extraGroups = [ "libvirtd" "kvm" ];

  #----- Remote desktop (Sunshine) -----
  # Streams the live i3 session on :0 to Moonlight. Pair through the web UI:
  # `ssh -L 47990:localhost:47990 base`, then https://localhost:47990.
  # X11 capture, encoded by the iGPU's Quick Sync over VA-API, so streaming
  # never touches the NVIDIA cards.
  services.sunshine = {
    enable = true;
    settings = {
      capture = "x11";
      encoder = "vaapi";
      adapter_name = "/dev/dri/by-path/pci-0000:00:02.0-render";
      # The ultrawide only; the default streams every monitor at once. Was 2
      # on the 1080; check the index in Sunshine's log after the move.
      output_name = 2;
    };
  };

  #----- Network -----
  # LAN access to T3 Code, xrdp, Unsloth Studio and Sunshine over the onboard I219-V
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i enp0s31f6 -p tcp --dport 3773 -s 192.168.0.0/24 -j nixos-fw-accept
    iptables -A nixos-fw -i enp0s31f6 -p tcp --dport 3389 -s 192.168.0.0/24 -j nixos-fw-accept
    iptables -A nixos-fw -i enp0s31f6 -p tcp --dport 8888 -s 192.168.0.0/24 -j nixos-fw-accept
    iptables -A nixos-fw -i enp0s31f6 -p tcp -m multiport --dports 47984,47989,48010 -s 192.168.0.0/24 -j nixos-fw-accept
    iptables -A nixos-fw -i enp0s31f6 -p udp -m multiport --dports 47998:48000,48002,48010 -s 192.168.0.0/24 -j nixos-fw-accept
    # xrdp and Unsloth Studio from Meshnet peers (off-LAN)
    iptables -A nixos-fw -i nordlynx -p tcp --dport 3389 -s 100.64.0.0/10 -j nixos-fw-accept
    iptables -A nixos-fw -i nordlynx -p tcp --dport 8888 -s 100.64.0.0/10 -j nixos-fw-accept
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. Leave it at the release of the first install.
  system.stateVersion = "26.05"; # Did you read the comment?
}
