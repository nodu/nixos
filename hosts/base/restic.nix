# Off-site copy of the `data` pool: an encrypted restic repository in Google
# Drive, through the gdrive: remote in matt's rclone.conf.
#
# The password is in ~/.secrets/restic-password and in the password manager.
# Without it this repository can never be read.
#
# `paths` stays the whole pool. restic picks the previous snapshot with the
# same `paths` as the parent and skips unchanged files; a different list means
# rereading everything. So hold data back with `exclude`, not by narrowing
# `paths`. Files moved out of the inbox are read again but not re-uploaded.
#
# Run by hand:
#   sudo systemctl start --no-block restic-backups-base
#   journalctl -fu restic-backups-base
# Once the initial upload is done, set timerConfig for the nightly run and add
# pruneOpts.

{ ... }:

{
  services.restic.backups.base = {
    repository = "rclone:gdrive:restic/base";
    passwordFile = "/home/matt/.secrets/restic-password";
    rcloneConfigFile = "/home/matt/.config/rclone/rclone.conf";
    # matt, not root: rclone rewrites rclone.conf when it refreshes the token
    user = "matt";
    initialize = true;

    paths = [ "/data" ];
    exclude = [ ];
    # Fewer, larger files in Drive than the 16 MiB default
    extraBackupArgs = [ "--pack-size=128" ];

    # Manual until the initial upload is done
    timerConfig = null;
  };
}
