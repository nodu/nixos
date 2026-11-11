# Disk layout declared for disko: the `data` pool, a ZFS mirror of two WD Red
# Plus 6TB (WD60EFPX), and `/cache` on the failing Tanker SSD. The NVMe root
# stays the hand-made ext4 in ./hardware-configuration.nix.
#
# disko generates the fileSystems entries from this. It never formats on
# `nixos-rebuild switch`; the format scripts below are one-time, explicit runs.
#
# Don't rerun zfsDiskoFormatScript now the pool exists. It skips an existing
# pool, but sgdisk still rewrites the partition GUIDs on the live pool disks.
# To add a dataset, follow ./INSTALL.md, "Storage pool".

{ config, extendModules, lib, ... }:

let
  disk = serial: {
    type = "disk";
    device = "/dev/disk/by-id/ata-WDC_WD60EFPX-68C5ZN0_${serial}";
    content = {
      type = "gpt";
      partitions.zfs = {
        size = "100%";
        content = {
          type = "zfs";
          pool = "data";
        };
      };
    };
  };

  # nofail: if the pool can't be imported, boot carries on without /data
  # instead of stopping in emergency mode.
  dataset = mountpoint: extra: {
    type = "zfs_fs";
    inherit mountpoint;
    mountOptions = [ "nofail" ];
  } // extra;

  # Samsung 870 EVO with bad flash (589 reallocated blocks, stable through a
  # full write test on 2026-11-10). Re-downloadable data only. nofail and a
  # short timeout, so a dead drive can't hold up boot.
  cacheDisk = {
    type = "disk";
    device = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_2TB_S620NG0R308004Y";
    content = {
      type = "gpt";
      partitions.cache = {
        size = "100%";
        content = {
          type = "filesystem";
          format = "ext4";
          extraArgs = [ "-L" "cache" "-m" "0" ];
          mountpoint = "/cache";
          mountOptions = [ "nofail" "noatime" "errors=remount-ro" "x-systemd.device-timeout=10s" ];
        };
      };
    };
  };
in
{
  # Alias for disko's format script:
  # sudo "$(nix build --no-link --print-out-paths .#nixosConfigurations.base.config.system.build.zfsDiskoFormatScript)"
  system.build.zfsDiskoFormatScript = config.system.build.formatScript;

  # Formats only the cache disk, so it can't touch the pool's partitions:
  # sudo "$(nix build --no-link --print-out-paths .#nixosConfigurations.base.config.system.build.cacheDiskoFormatScript)"
  system.build.cacheDiskoFormatScript =
    (extendModules {
      modules = [{
        disko.devices.disk = lib.mkForce { cache = cacheDisk; };
        disko.devices.zpool = lib.mkForce { };
      }];
    }).config.system.build.formatScript;

  disko.devices = {
    disk = {
      data1 = disk "WD-WX22D76D4X50";
      data2 = disk "WD-WX22D76D45L2";
      cache = cacheDisk;
    };

    zpool.data = {
      type = "zpool";
      mode = "mirror";
      options.ashift = "12"; # 4K sectors
      # Inherited by every dataset
      rootFsOptions = {
        compression = "zstd";
        atime = "off";
        xattr = "sa";
        acltype = "posixacl";
        dnodesize = "auto";
        normalization = "formD"; # can only be set at creation
      };
      mountpoint = "/data";
      mountOptions = [ "nofail" ];

      datasets = {
        library = dataset "/data/library" { }; # photos, documents, music
        # Films/TV: large files written once, so big records
        media = dataset "/data/media" { options.recordsize = "1M"; };
        backups = dataset "/data/backups" { };
        "backups/mac" = dataset "/data/backups/mac" { };
        "backups/baremetal" = dataset "/data/backups/baremetal" { };
        "backups/bau" = dataset "/data/backups/bau" { };
        inbox = dataset "/data/inbox" { }; # scratch space, no snapshots
      };
    };
  };
}
