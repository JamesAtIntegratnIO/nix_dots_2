# Off-node target for Hermes Agent's nightly backup.
#
# Hermes keeps all its state (state.db, memories, skills, sessions, cron jobs)
# on one local NVMe claim on the Pi 5 worker. A CronJob in the cluster
# (gitops_homelab_2_0, addons/.../hermes/hermes-backup.yaml) runs
# `hermes backup` there every night and writes the zip into this export,
# keeping the newest 14. Not Tower: see backup.nix for why nothing writes there.
#
# One client only: talos-pi5-1 (10.0.4.104). The kubelet mounts the export, so
# the address the server sees is the node's. NFSv4 only, so 2049 is the one
# port, open to that address alone. Every client uid is squashed to
# hermes-backup, and the directory is 0700, because the zips hold Hermes's
# .env and auth.json.
{ ... }:

let
  dir = "/srv/backups/hermes";
  client = "10.0.4.104";
  uid = 10000;
in
{
  users.groups.hermes-backup.gid = uid;
  users.users.hermes-backup = {
    isSystemUser = true;
    inherit uid;
    group = "hermes-backup";
    description = "Owner of the Hermes Agent backup export";
  };

  systemd.tmpfiles.rules = [
    "d /srv/backups 0755 root root -"
    "d ${dir} 0700 hermes-backup hermes-backup -"
  ];

  services.nfs.server = {
    enable = true;
    exports = ''
      ${dir} ${client}(rw,sync,all_squash,anonuid=${toString uid},anongid=${toString uid},no_subtree_check,sec=sys)
    '';
  };
  services.nfs.settings.nfsd = {
    vers3 = false;
    vers4 = true;
  };

  networking.firewall.extraInputRules = ''
    ip saddr ${client} tcp dport 2049 accept
  '';
}
