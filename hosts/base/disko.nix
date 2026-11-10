# Disk layout of the `data` pool: a ZFS mirror of two WD Red Plus 6TB
# (WD60EFPX), declared for disko. Only these two disks; the NVMe root stays
# the hand-made ext4 in ./hardware-configuration.nix.
#
# disko generates the fileSystems entries from this. It never formats on
# `nixos-rebuild switch`: creating the pool, or a dataset added here later, is
# an explicit run of the format script (./INSTALL.md, "Storage pool"). That
# script skips a pool that already exists, and skips a disk that already holds
# partitions or a filesystem. On a rerun it creates only missing datasets and
# `zfs set`s the properties below on existing ones.

{ config, ... }:

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
in
{
  # Alias for disko's format script:
  # sudo "$(nix build --no-link --print-out-paths .#nixosConfigurations.base.config.system.build.zfsDiskoFormatScript)"
  system.build.zfsDiskoFormatScript = config.system.build.formatScript;

  disko.devices = {
    disk = {
      data1 = disk "WD-WX22D76D4X50";
      data2 = disk "WD-WX22D76D45L2";
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
