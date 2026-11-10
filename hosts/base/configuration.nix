# Desktop workstation + always-on server: i7-6700K on an ASUS Maximus VIII
# Hero. GTX 1080 drives the host display. RTX 3090 serves host CUDA (Unsloth
# Studio) and is lent to the Windows VM while it runs. Shared desktop/server
# config lives in ../../modules/workstation.nix. Install steps are in
# ./INSTALL.md.

{ config, pkgs, lib, ... }:

let
  # lspci -nn: 01:00.0 [10de:2204] RTX 3090, 01:00.1 [10de:1aef] its HDMI audio.
  # The 1080 (10de:1b80, 10de:10f0) has different IDs, so binding by ID is safe.
  rtx3090Ids = "10de:2204,10de:1aef";
  rtx3090 = "0000:01:00.0";

  # libvirt qemu hook, called as `<domain> <operation> <sub-operation>`. Before
  # the win11 VM takes the 3090, checks that nothing on the host has it open.
  #
  # The detach is an unbind of nvidia from the card. If a process still has
  # the card open (e.g. Unsloth Studio with a model loaded), the unbind blocks
  # instead of failing, and the VM start hangs. So refuse to start, naming the
  # holders, rather than risk that.
  gpuPassthroughHook = pkgs.writeShellApplication {
    name = "rtx3090-passthrough-hook";
    runtimeInputs = [ pkgs.gawk pkgs.psmisc ];
    text = ''
      [ "$1" = win11 ] || exit 0
      case "$2" in
        prepare)
          info=/proc/driver/nvidia/gpus/${rtx3090}/information
          # Absent when the 3090 is already on vfio-pci (vfio-boot entry)
          [ -r "$info" ] || exit 0
          nodes="/dev/nvidia$(awk '/Device Minor/ {print $3}' "$info")"
          for n in /dev/dri/by-path/pci-${rtx3090}-card /dev/dri/by-path/pci-${rtx3090}-render; do
            if [ -e "$n" ]; then nodes="$nodes $n"; fi
          done
          # shellcheck disable=SC2086
          if fuser -s $nodes; then
            echo "RTX 3090 is still in use, not detaching it:" >&2
            # shellcheck disable=SC2086
            fuser -v $nodes >&2 || true
            exit 1
          fi
          ;;
      esac
    '';
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix # the data pool's disks and datasets; goes with zfs.nix
    ./zfs.nix
    ./restic.nix
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

  #----- NVIDIA (host display on the 1080) -----
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    # The GTX 1080 is Pascal: it has no open kernel module, and the 590+
    # drivers (`production` is 595 in 26.05) dropped it. 580 is NVIDIA's
    # long-term branch for Maxwell/Pascal/Volta, supported until Aug 2028, and
    # drives the 3090 too.
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    modesetting.enable = true;
    nvidiaSettings = true;
    # Off: nvidia-persistenced holds every GPU open, which would block lending
    # the 3090 to the VM.
    nvidiaPersistenced = false;
  };

  # GDM's Wayland greeter fails to hand the NVIDIA display over to Xorg/i3.
  # GNOME 50 no longer supports an X11 GDM greeter; use LightDM on this host.
  services.displayManager.gdm.enable = lib.mkForce false;
  services.xserver.displayManager.lightdm.enable = true;

  # Keep the desktop off the 3090 so it can be detached for the VM. Xorg is
  # pinned to the 1080 (05:00.0, behind the chipset), and ProbeAllGpus stops
  # the nvidia X driver opening the other card anyway. The GDM greeter runs
  # on mutter, which skips devices tagged mutter-device-ignore.
  services.xserver.deviceSection = ''
    BusID "PCI:5:0:0"
    Option "ProbeAllGpus" "false"
  '';
  # Without this the ultrawide comes up at 60 Hz; it does 120 over DP. Set at
  # the X server so LightDM and i3 both get it.
  services.xserver.screenSection = ''
    Option "metamodes" "HDMI-0: 3840x2400_60 +0+0, DP-0: 3440x1440_120 +3840+0"
  '';
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNELS=="${rtx3090}", TAG+="mutter-device-ignore"
  '';

  # GPUs in docker: `docker run --device nvidia.com/gpu=all ...`
  hardware.nvidia-container-toolkit.enable = true;

  # Prebuilt CUDA-enabled packages; otherwise anything built with CUDA support
  # compiles locally
  nix.settings = {
    substituters = [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };

  #----- Windows VM -----
  # VT-d is on in firmware (ACPI DMAR present); the kernel needs intel_iommu=on.
  # The 3090 sits alone on the CPU's x16 root port, so it gets its own IOMMU
  # group.
  boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
  boot.initrd.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" ];

  # Add the 3090 (01:00.0 and 01:00.1) to the VM as managed PCI host devices
  # (virt-manager's default). libvirt then moves the card from nvidia to
  # vfio-pci on VM start and back to nvidia on shutdown.
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true; # TPM 2.0 for Windows 11
    hooks.qemu.rtx3090-passthrough = lib.getExe gpuPassthroughHook;
  };
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;
  users.users.matt.extraGroups = [ "libvirtd" "kvm" ];

  # Fallback in case the runtime handoff misbehaves: a "vfio-boot" boot entry
  # that gives the 3090 to vfio-pci from early boot. The host loses it for
  # CUDA in that entry, but nothing has to be detached at VM start.
  specialisation.vfio-boot.configuration = {
    system.nixos.tags = [ "vfio-boot" ];
    boot.kernelParams = [
      "vfio-pci.ids=${rtx3090Ids}"
      # The 3090 is the boot VGA card (the firmware always initializes the
      # x16 slot). In this entry nvidia-drm never takes it over, so stop the
      # early framebuffer (simpledrm) from holding its memory.
      "initcall_blacklist=sysfb_init"
    ];
  };

  #----- Remote desktop (Sunshine) -----
  # Streams the live i3 session on :0 to Moonlight. Pair through the web UI:
  # `ssh -L 47990:localhost:47990 base`, then https://localhost:47990.
  # X11 capture rather than KMS, so Sunshine never opens the 3090's DRM nodes
  # (which would block lending it to the VM); NVENC is pinned to the 1080.
  services.sunshine = {
    enable = true;
    package = pkgs.sunshine.override { cudaSupport = true; };
    settings = {
      capture = "x11";
      encoder = "nvenc";
      # The ultrawide (DP-0) only; the default streams every monitor at once
      output_name = 2;
    };
  };
  systemd.user.services.sunshine.environment.CUDA_VISIBLE_DEVICES =
    "GPU-1e68a55a-03e0-d1eb-f9f9-69c560b1b2ef";

  #----- Network -----
  # LAN access to T3 Code, xrdp, Unsloth Studio and Sunshine over the onboard I219-V
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i enp0s31f6 -p tcp --dport 3773 -s 192.168.0.0/24 -j nixos-fw-accept
    iptables -A nixos-fw -i enp0s31f6 -p tcp --dport 3389 -s 192.168.0.0/24 -j nixos-fw-accept
    iptables -A nixos-fw -i enp0s31f6 -p tcp --dport 8888 -s 192.168.0.0/24 -j nixos-fw-accept
    iptables -A nixos-fw -i enp0s31f6 -p tcp -m multiport --dports 47984,47989,48010 -s 192.168.0.0/24 -j nixos-fw-accept
    iptables -A nixos-fw -i enp0s31f6 -p udp -m multiport --dports 47998:48000,48002,48010 -s 192.168.0.0/24 -j nixos-fw-accept
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. Leave it at the release of the first install.
  system.stateVersion = "26.05"; # Did you read the comment?
}
