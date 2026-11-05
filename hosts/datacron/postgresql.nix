# Postgres 18 for every database the homelab has: all of CT101's and CT111's,
# merged on 2026-11-05's inventory (docs/datacron/RUNBOOK.md has the list and
# where each came from).
#
# What lives here: the major version, the settings, who may connect, and which
# roles and databases exist with which owner. What does not: passwords. They
# live in the cluster's own pg_authid, copied over from the old servers at
# restore time, and the apps' copies stay in 1Password / the cluster's
# ExternalSecrets. Nothing secret enters the Nix store.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  pg = config.services.postgresql;
  clients = config.homelab.postgres.allowedClients;

  hbaLine =
    c:
    "${
      if c.ssl then "hostssl" else "host   "
    } ${c.databases} ${c.users} ${c.address} ${c.method} # ${c.name}\n";

  # Roles and their attributes. Every role from both old servers, attributes
  # as they were. `postgres` is created by initdb and is not listed.
  roles = {
    authentik = { };
    backstage.createdb = true;
    hassio.createdb = true;
    keycloak_user = { };
    n8n = { };
    paperclip = { };
    paperless = { };
    radarr = { };
    root = {
      superuser = true;
      createdb = true;
      createrole = true;
    };
    scanopy = { };
    sonarr = { };
    specmarshal = { };
    terraform.createdb = true;
    umami = { };
  };

  # Database -> owner, as on the old servers. authentik and paperless are
  # CT111's live databases; CT101's stale copies come over renamed with a
  # _ct101 suffix. Both old `root` databases were empty; one is kept.
  databases = {
    # from CT111 (postgres2)
    authentik = "authentik";
    paperless = "paperless";
    paperclip = "root";
    # from CT101 (postgres)
    authentik_ct101 = "authentik";
    paperless_ct101 = "paperless";
    backstage = "postgres";
    backstage_plugin_app = "backstage";
    backstage_plugin_auth = "backstage";
    backstage_plugin_catalog = "backstage";
    backstage_plugin_kubernetes = "backstage";
    backstage_plugin_permission = "backstage";
    backstage_plugin_proxy = "backstage";
    backstage_plugin_scaffolder = "backstage";
    backstage_plugin_search = "backstage";
    backstage_plugin_techdocs = "backstage";
    hass_db = "postgres";
    keycloak = "root";
    keycloak_db = "root";
    n8n = "root";
    radarr = "radarr";
    radarrlogs = "radarr";
    root = "postgres";
    scanopy = "root";
    sonarr = "sonarr";
    sonarrlogs = "sonarr";
    specmarshal = "specmarshal";
    terraform_kratix_cluster = "root";
    terraform_lenovo_cluster = "terraform";
    terraform_media_cluster = "terraform";
    terraform_state = "terraform";
    umami = "umami";
  };

  sslDir = "/var/lib/postgresql/ssl";
in
{
  options.homelab.postgres.allowedClients = lib.mkOption {
    description = ''
      Who may connect to Postgres over the network. Each entry becomes one
      pg_hba.conf line (after the local peer lines) and its address is let
      through the firewall on 5432. Set in hosts/datacron/default.nix.
    '';
    default = [ ];
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "What this client is; ends up as a comment on its pg_hba line.";
          };
          address = lib.mkOption {
            type = lib.types.str;
            example = "10.0.4.0/24";
            description = "Source address in CIDR form.";
          };
          databases = lib.mkOption {
            type = lib.types.str;
            default = "all";
            description = "pg_hba DATABASE field, e.g. all or a comma list.";
          };
          users = lib.mkOption {
            type = lib.types.str;
            default = "all";
            description = "pg_hba USER field.";
          };
          method = lib.mkOption {
            type = lib.types.enum [
              "scram-sha-256"
              "md5"
              "reject"
            ];
            default = "scram-sha-256";
            description = ''
              Auth method. md5 also accepts roles with scram hashes, so it is the
              escape hatch for a client whose role still has an md5 hash from
              the old servers; scram-sha-256 is the goal.
            '';
          };
          ssl = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              true renders hostssl (TLS required); false renders host (TLS or
              plain). The current clients connect without TLS.
            '';
          };
        };
      }
    );
  };

  config = {
    services.postgresql = {
      enable = true;
      # Pinned, never left to stateVersion: a flake bump must not change the
      # major version under the data directory. Moving to 19 is a deliberate
      # pg_upgrade, not a side effect of `nix flake update`.
      package = pkgs.postgresql_18;
      enableTCPIP = true;

      # uuid-ossp, pgcrypto, pg_trgm and fuzzystrmatch are contrib modules and
      # ship with the server package. PostGIS was installed on both old servers
      # but no database used it, so it is not here.

      settings = {
        ssl = true;
        ssl_cert_file = "${sslDir}/server.crt";
        ssl_key_file = "${sslDir}/server.key";
        password_encryption = "scram-sha-256";

        # authentik alone opened ~90 connections reconnecting after the
        # 2026-11-05 cutover, which filled 100 and locked it out.
        max_connections = 200;

        # Sized for 2 vCPU / 4 GB with nothing else on the box.
        shared_buffers = "1GB";
        effective_cache_size = "3GB";
        maintenance_work_mem = "256MB";
        work_mem = "8MB";
        wal_buffers = "16MB";
        min_wal_size = "512MB";
        max_wal_size = "2GB";
        checkpoint_completion_target = 0.9;
        # The disk is a zvol on the host's SSD pool.
        random_page_cost = 1.1;
        effective_io_concurrency = 200;

        # %h puts the client address on every line, failed logins included.
        # On CT101 they had none, so nobody could tell where a failure came from.
        log_line_prefix = "%m [%p] %q%u@%d %h ";
      };

      # Local peer for the OS users, then one line per allowedClients entry.
      authentication = lib.mkForce (
        ''
          # TYPE  DATABASE  USER      ADDRESS  METHOD
          local   all       postgres           peer
          local   all       all                peer
        ''
        + lib.concatMapStrings hbaLine clients
      );

      ensureUsers = lib.mapAttrsToList (name: clauses: {
        inherit name;
        ensureClauses = {
          login = true;
        }
        // clauses;
      }) roles;

      ensureDatabases = lib.attrNames databases;
    };

    # ensureDatabases creates databases owned by postgres, and ensureDBOwnership
    # only covers a database named after its owner. This sets every owner from
    # the table above, on each start, so ownership is declared here and nowhere
    # else.
    systemd.services.postgresql-db-owners = {
      description = "Set Postgres database owners";
      # postgresql-setup is where NixOS runs ensureUsers/ensureDatabases;
      # ordering after postgresql alone races it and finds no roles yet.
      after = [ "postgresql-setup.service" ];
      requires = [ "postgresql-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        RemainAfterExit = true;
      };
      script = lib.concatStrings (
        lib.mapAttrsToList (db: owner: ''
          ${pg.package}/bin/psql -X -v ON_ERROR_STOP=1 -d postgres -c 'ALTER DATABASE "${db}" OWNER TO "${owner}"'
        '') databases
      );
    };

    # A self-signed certificate, made once on first boot and kept with the data.
    # The clients use sslmode=disable or prefer today; anything that wants
    # verify-full can be given a proper cert later.
    systemd.services.postgresql-ssl-cert = {
      description = "Create Postgres TLS certificate";
      before = [ "postgresql.service" ];
      requiredBy = [ "postgresql.service" ];
      unitConfig.ConditionPathExists = "!${sslDir}/server.key";
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        StateDirectory = "postgresql";
      };
      script = ''
        install -d -m 0700 ${sslDir}
        ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:3072 -nodes -days 3650 \
          -subj "/CN=${config.networking.hostName}" \
          -keyout ${sslDir}/server.key -out ${sslDir}/server.crt
        chmod 0600 ${sslDir}/server.key
      '';
    };

    # 5432 from the allowedClients addresses and nowhere else.
    networking.nftables.enable = true;
    networking.firewall.extraInputRules = lib.mkIf (clients != [ ]) ''
      ip saddr { ${
        lib.concatMapStringsSep ", " (c: c.address) (lib.unique clients)
      } } tcp dport 5432 accept
    '';
  };
}
