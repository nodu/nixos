# ZFS pool `data`: the primary copy of the library and the backup target for
# the other machines. Google Drive (restic) is the off-site copy.
#
# The disks, pool and datasets are declared in ./disko.nix, which also
# generates their fileSystems entries (so NixOS imports the pool at boot).
# This module scrubs and snapshots it.
#
# A mirror of two WD Red Plus 6TB (WD60EFPX): either disk can fail, and a
# scrub repairs a bad block from the other copy.

{ ... }:

{
  # ZFS refuses to import a pool last used by a different host ID.
  # First 8 hex digits of /etc/machine-id.
  networking.hostId = "420df512";

  boot.supportedFilesystems = [ "zfs" ];
  # Import through disko's partition labels, so `zpool status` shows the names
  # declared in ./disko.nix (disk-data1-zfs) instead of wwn-... from by-id.
  boot.zfs.devNodes = "/dev/disk/by-partlabel";
  # Never force-import a pool another host ID last used (26.11's default).
  boot.zfs.forceImportRoot = false;

  # The ARC would otherwise grow to half of RAM (16 GiB). Cap it at 8 GiB, so
  # Unsloth models and games keep their memory.
  boot.kernelParams = [ "zfs.zfs_arc_max=${toString (8 * 1024 * 1024 * 1024)}" ];

  # Reads every block and checks it against its checksum.
  services.zfs.autoScrub = {
    enable = true;
    pools = [ "data" ];
    interval = "monthly";
  };

  # ZED logs pool events (device faults, checksum errors, scrub results) to
  # the journal: `journalctl -u zfs-zed`.
  # TODO: push to the phone through the homebase ntfy server (baremetal :2586),
  # with ZED_NTFY_URL and ZED_NTFY_TOPIC, along with smartd's warnings.
  services.zfs.zed.settings = {
    ZED_NOTIFY_VERBOSE = true; # also report scrubs that finish clean
  };

  # Snapshots guard against accidental deletion or overwrites (not disk
  # failure). Browse them under <mountpoint>/.zfs/snapshot/.
  services.sanoid = {
    enable = true;
    templates = {
      library = {
        hourly = 24;
        daily = 30;
        monthly = 12;
        autosnap = true;
        autoprune = true;
      };
      # Large files that rarely change. Unset counts fall back to sanoid's
      # defaults (hourly = 48), so hourly is set explicitly.
      media = {
        hourly = 0;
        daily = 14;
        monthly = 2;
        autosnap = true;
        autoprune = true;
      };
    };
    datasets = {
      "data/library".useTemplate = [ "library" ];
      "data/media".useTemplate = [ "media" ];
      # restic repositories keep their own history, but a snapshot still
      # undoes a client that wipes its repository.
      "data/backups" = {
        useTemplate = [ "media" ];
        recursive = true;
      };
      # data/inbox is scratch space: no snapshots.
    };
  };
}
