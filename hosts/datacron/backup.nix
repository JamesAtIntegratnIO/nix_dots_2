# Nightly backups: one pg_dump per database on the VM's own disk. A dated copy
# on Tower over NFS is written below but switched off.
#
# Off because on 2026-11-05 a vzdump writing to Tower's NFS export hung Tower
# (its USB boot flash reset under the load) and took cluster workloads down
# with it. Nothing writes to Tower until James says otherwise. The off-box copy
# is going to be a nightly pull from holocron instead (not built yet).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  shipToTower = false;
  local = config.services.postgresqlBackup.location;
  remote = "/mnt/tower-backups";
  keepDays = 30;
in
lib.mkMerge [
  {
    services.postgresqlBackup = {
      enable = true;
      # Every database the server declares, each in its own file.
      databases = config.services.postgresql.ensureDatabases;
      location = "/var/backup/postgresql";
      compression = "zstd";
      startAt = "*-*-* 02:15:00";
    };
  }

  (lib.mkIf shipToTower {
    # Tower exports with all_squash to nobody (99:100), so files land there as
    # nobody whatever user writes them.
    fileSystems.${remote} = {
      device = "10.0.0.12:/mnt/user/data/backups/datacron";
      fsType = "nfs";
      options = [
        "nfsvers=4.2"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=600"
        "soft"
        "timeo=150"
      ];
    };

    systemd.services.postgresql-backup-ship = {
      description = "Copy the night's Postgres dumps to Tower";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.RequiresMountsFor = remote;
      serviceConfig.Type = "oneshot";
      path = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.rsync
      ];
      script = ''
        day=$(date +%F)
        mkdir -p ${remote}/$day
        # Only the current dumps; postgresqlBackup keeps a .prev beside each.
        rsync -rt --no-perms --no-owner --no-group \
          --exclude '*.prev*' ${local}/ ${remote}/$day/
        find ${remote} -mindepth 1 -maxdepth 1 -type d -mtime +${toString keepDays} \
          -exec rm -rf {} +
      '';
      startAt = "*-*-* 03:30:00";
    };
  })
]
