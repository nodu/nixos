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
# Runs nightly; a failed run is retried every hour until one succeeds (Drive's
# 750 GB/day upload limit stops a big upload partway; a network drop is retried
# too). A reboot ends the run without a retry; the next nightly run resumes it.
# Uploaded data is never sent twice.
#   sudo systemctl start --no-block restic-backups-base    # run now
#   journalctl -fu restic-backups-base
#
# After each backup, forget --prune applies the retention below and deletes
# data no kept snapshot uses. A deleted file stays restorable for as long as a
# kept snapshot still holds it, up to 3 years. Retention applies per group of
# snapshots with the same `paths`, so a snapshot taken with a different list
# is never pruned and has to be forgotten by hand.

{ ... }:

{
  services.restic.backups.base = {
    repository = "rclone:gdrive:restic/base";
    passwordFile = "/home/matt/.secrets/restic-password";
    rcloneConfigFile = "/home/matt/.config/rclone/rclone.conf";
    # matt, not root: rclone rewrites rclone.conf when it refreshes the token
    user = "matt";
    # The repository exists. With true, a failed read of its config (Drive
    # refusing requests, say) makes the service try `restic init`.
    initialize = false;

    paths = [ "/data" ];
    exclude = [ ];
    # Fewer, larger files in Drive than the 16 MiB default
    extraBackupArgs = [ "--pack-size=128" ];

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
      "--keep-yearly 3"
    ];

    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true; # catch up after a night the machine was off
    };
  };

  systemd.services.restic-backups-base = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "1h";
    };
    # Never give up retrying (the default stops after 5 starts in 10s)
    unitConfig.StartLimitIntervalSec = 0;
  };
}
