# Raspberry Pi 4 hardware configuration
# Partition layout (1TB SD card):
#   sda1 / mmcblk0p1: 30M vfat   -> /boot/firmware
#   sda2 / mmcblk0p2: ~232.8G ext4 -> /         (root)
#   sda3 / mmcblk0p3: ~720.8G ext4 -> /mnt/data (Docker volumes / media)

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # SD card image builder -- uncomment to rebuild image, then re-comment
    #   make bau/sd-image
    # (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "v3d" "vc4" "ip_tables" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
    fsType = "ext4";
  };

  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-uuid/2178-694E";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/3cc1f0c3-1be4-4e38-81c8-42c9acf09426";
    fsType = "ext4";
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
