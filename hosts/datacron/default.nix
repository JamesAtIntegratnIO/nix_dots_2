# datacron: the homelab's one Postgres server. A VM on the Proxmox host at
# 192.168.0.10, on the Homelab VLAN (tag 25), replacing the TurnKey containers
# CT101 (postgres, 10.0.3.1) and CT111 (postgres2, 10.0.3.24). The runbook for
# building it and moving the databases over is docs/datacron/RUNBOOK.md.
{
  inputs,
  modulesPath,
  ...
}:

let
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIESq1wdY7diOloASvawJgjjThP6kzDWC/J3NIzZu5QVe james@integratn.io";

  # The one line that changes at cutover. While the databases are restored the
  # VM sits on a spare address; at cutover CT101 is stopped and this becomes
  # 10.0.3.1, so sonarr, radarr, umami, specmarshal and the cluster's
  # 10.0.3.1/32 network policies need no change.
  address = "10.0.3.5";
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./postgresql.nix
    ./backup.nix
    ../../modules/nixos/core/locale.nix
    ../../modules/nixos/core/nix.nix
    ../../modules/nixos/host-metrics.nix
  ];

  # ── Who may connect to Postgres ──────────────────────────────────────────
  # One entry per client. Each becomes a pg_hba.conf line and a firewall
  # allowance on 5432 (rendered in ./postgresql.nix); nothing else gets in.
  # Defaults: databases = "all", users = "all", method = "scram-sha-256",
  # ssl = false (host; true makes it hostssl). Adding or removing a client
  # is an edit here and nowhere else.
  homelab.postgres.allowedClients = [
    {
      name = "k8s-nodes";
      # the-cluster (authentik, umami, specmarshal) and vcluster-media
      # (sonarr, radarr). Pods leave the cluster with their node's address.
      address = "10.0.4.0/24";
    }
    {
      name = "tower-br0";
      # Tower's br0 containers: paperless-ngx (live), n8n, scanopy.
      address = "10.0.3.3/32";
    }
    {
      name = "tower-host";
      # Tower itself and its bridge-network containers, i.e. Paperclip.
      address = "10.0.0.12/32";
    }
    {
      name = "home-assistant";
      # VM 201. HA records to SQLite today; hass_db is kept for it.
      address = "10.0.1.174/32";
    }
    {
      name = "holocron";
      # The Mac Studio, for psql and the migration. It reaches VLAN 25 from
      # the main LAN (en0 192.168.0.57), so that is the address Postgres sees.
      address = "192.168.0.57/32";
      # OpenTofu's pg backend runs from here with PGUSER/PGPASSWORD from
      # gitops_homelab_2_0's secrets.env, and that role still has the md5
      # hash copied from CT101. md5 accepts md5 and scram hashes alike;
      # switch to scram-sha-256 once the role has been re-hashed.
      method = "md5";
    }
  ];

  networking.hostName = "datacron";

  # Static, not DHCP: every client and firewall rule names this address.
  # VLAN 25 is one /9 (10.0.0.0/9) with the UniFi gateway at 10.0.0.1, the
  # same settings CT101 has today.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en*";
    address = [ "${address}/9" ];
    gateway = [ "10.0.0.1" ];
    dns = [ "10.0.0.1" ];
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  services.qemuGuest.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [ sshKey ];
  users.users.jdreier = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ sshKey ];
  };
  security.sudo.wheelNeedsPassword = false;

  # Lets `nixos-rebuild --target-host` push closures built elsewhere.
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  # Keep this at the release used for the initial installation.
  system.stateVersion = "26.05";
}
