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

  # The one list that changes at cutover. 10.0.3.5 is the admin address and
  # stays first. At cutover CT101 and CT111 are stopped (onboot 0) and their
  # addresses are added here, 10.0.3.1 and 10.0.3.24, so no client gets
  # repointed: sonarr, radarr, umami, specmarshal and the cluster's
  # 10.0.3.1/32 network policies keep 10.0.3.1, and authentik's secret and
  # paperless on Tower keep 10.0.3.24.
  addresses = [ "10.0.3.5" ];
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
  #
  # Every entry is md5 for now (the map at the end). The roles came over from
  # the old servers with md5 hashes, and md5 accepts both md5 and scram hashes,
  # so nothing breaks at cutover. password_encryption stays scram, so any
  # password set here is stored as scram. Drop the map once
  # `select rolname from pg_authid where rolpassword like 'md5%'` is empty.
  homelab.postgres.allowedClients = map (c: c // { method = "md5"; }) [
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
      # hash copied from CT101.
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
    address = map (a: "${a}/9") addresses;
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
