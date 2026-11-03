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
    ../../modules/workstation.nix
  ];

  networking.hostName = "base";

  # No swap partition; 32 GB of RAM rarely needs disk swap.
  zramSwap.enable = true;

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

  # Keep the desktop off the 3090 so it can be detached for the VM. Xorg is
  # pinned to the 1080 (05:00.0, behind the chipset), and ProbeAllGpus stops
  # the nvidia X driver opening the other card anyway. The GDM greeter runs
  # on mutter, which skips devices tagged mutter-device-ignore.
  services.xserver.deviceSection = ''
    BusID "PCI:5:0:0"
    Option "ProbeAllGpus" "false"
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

  #----- Network -----
  # LAN access to T3 Code and xrdp over the onboard I219-V
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i enp0s31f6 -p tcp --dport 3773 -s 192.168.0.0/24 -j nixos-fw-accept
    iptables -A nixos-fw -i enp0s31f6 -p tcp --dport 3389 -s 192.168.0.0/24 -j nixos-fw-accept
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. Leave it at the release of the first install.
  system.stateVersion = "26.05"; # Did you read the comment?
}
