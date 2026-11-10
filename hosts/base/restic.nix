# Off-site copy of the `data` pool: an encrypted restic repository in Google
# Drive, through the gdrive: remote in matt's rclone.conf.
#
# The password is in ~/.secrets/restic-password and in the password manager.
# Without it this repository can never be read.
#
# Initial upload, in stages: add the next path to `paths`, switch, then
#   sudo systemctl start --no-block restic-backups-base
#   journalctl -fu restic-backups-base
# restic stores data by content, so files that move out of the inbox later
# aren't uploaded again. Once every stage is done, set timerConfig for the
# nightly run and add pruneOpts.

{ ... }:

{
  services.restic.backups.base = {
    repository = "rclone:gdrive:restic/base";
    passwordFile = "/home/matt/.secrets/restic-password";
    rcloneConfigFile = "/home/matt/.config/rclone/rclone.conf";
    # matt, not root: rclone rewrites rclone.conf when it refreshes the token
    user = "matt";
    initialize = true;

    paths = [
      "/data/inbox/tanker"
      "/data/inbox/baremetal"
      "/data/inbox/usb"
      "/data/inbox/sonic"
    ];
    # Fewer, larger files in Drive than the 16 MiB default
    extraBackupArgs = [ "--pack-size=128" ];

    # Manual until the initial upload is done
    timerConfig = null;
  };
}
