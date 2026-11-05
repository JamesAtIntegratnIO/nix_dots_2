# datacron: building it and moving every database onto it

datacron is a NixOS VM on the Proxmox host (`192.168.0.10`) running Postgres 18.
It replaces two TurnKey containers:

| Old | Address | Version | What runs on it |
|---|---|---|---|
| CT101 `postgres` | `10.0.3.1` | 13.23, Debian 11 (EOL) | sonarr, radarr, umami, specmarshal, terraform state, and a pile of dormant databases |
| CT111 `postgres2` | `10.0.3.24` | 15.19, Debian 12 | authentik, paperless, paperclip |

The config is `hosts/datacron/`. `default.nix` holds the address and the
`homelab.postgres.allowedClients` list, `postgresql.nix` holds the server
(version, settings, roles, databases and owners), and `backup.nix` the nightly
dumps. Passwords are never in Nix. They live in the cluster's `pg_authid`,
copied from the old servers in step 5.

Every database from both servers comes over. Nothing is dropped.

## The databases and where each comes from

| On datacron | From | Owner | In use (2026-11-05) |
|---|---|---|---|
| `authentik` | CT111 `authentik` | authentik | yes, k8s the-cluster |
| `paperless` | CT111 `paperless` | paperless | yes, Tower `paperless-ngx` |
| `paperclip` | CT111 `paperclip` | root | no, container stopped |
| **`authentik_ct101`** | CT101 `authentik` (**renamed**) | authentik | no, stale copy |
| **`paperless_ct101`** | CT101 `paperless` (**renamed**) | paperless | no, stale copy |
| `sonarr`, `sonarrlogs` | CT101 | sonarr | yes, vcluster-media |
| `radarr`, `radarrlogs` | CT101 | radarr | yes, vcluster-media |
| `umami` | CT101 | umami | yes, light |
| `specmarshal` | CT101 | specmarshal | yes, light |
| `terraform_state`, `terraform_lenovo_cluster`, `terraform_media_cluster` | CT101 | terraform | rarely, OpenTofu pg backend |
| `terraform_kratix_cluster` | CT101 | root | rarely |
| `hass_db` | CT101 | postgres | no, HA records to SQLite |
| `n8n`, `keycloak`, `keycloak_db`, `scanopy` | CT101 | root | no |
| `backstage` | CT101 | postgres | no |
| `backstage_plugin_*` (9) | CT101 | backstage | no |
| `root` | CT101 | postgres | no; both servers' `root` DBs were empty, so one is kept |

**Renames.** authentik and paperless exist on both servers. CT111's are live
and keep their names. CT101's copies come over as `authentik_ct101` and
`paperless_ct101`, so nothing is lost and nothing collides.

**Roles.** Every role from both servers keeps its attributes (see `roles` in
`postgresql.nix`). Where a role exists on both, the password hash comes from
the server whose database is live: `authentik` and `paperless` from CT111,
`root` from CT101 (CT111's `root` had no password).

## Clients and pg_hba

`homelab.postgres.allowedClients` at the top of `hosts/datacron/default.nix`
is the only place a client gets let in. Each entry becomes one pg_hba line and
one firewall allowance on 5432. The default method is `scram-sha-256`.

Every role on CT101, plus CT111's `paperless`, still has an **md5** hash. A role
with an md5 hash cannot log in through a `scram-sha-256` line, so step 6
re-hashes every role whose password we know before its app cuts over. If one
can't be re-hashed in time, give its client entry `method = "md5"` (md5 also
accepts scram hashes) and take it out again once the role is re-hashed.

## 0. Before anything: safety copies (no downtime)

```bash
# Proxmox-level copies of both old containers.
ssh root@192.168.0.10 'vzdump 101 111 --mode snapshot --compress zstd --storage local'
```

The off-box backup target is `10.0.0.12:/mnt/user/data/backups/datacron`. The
directory has to exist before the first night (writing on Tower needs James's
OK):

```bash
ssh root@10.0.0.12 'mkdir -p /mnt/user/data/backups/datacron'
```

## 1. Commit and push

Commit `hosts/datacron`, `flake.nix` and this file to `main` and push. Never
deploy from a branch.

## 2. Create the VM (VMID 103, the next free one)

The VM is shaped like pitdroid (VM 120): OVMF, q35, virtio-scsi-single, guest
agent, VLAN 25. pitdroid was installed by booting the Debian 13 generic cloud
image with cloud-init SSH keys and running nixos-anywhere over it. datacron
does the same. Use 2 vCPU, 4 GB and a 40G disk.

```bash
ssh root@192.168.0.10 '
qm create 103 --name datacron --machine q35 --bios ovmf --ostype l26 \
  --cores 2 --cpu host --memory 4096 --balloon 0 --agent enabled=1 --onboot 1 \
  --scsihw virtio-scsi-single --net0 virtio,bridge=vmbr0,tag=25 \
  --efidisk0 local-zfs:1,efitype=4m,pre-enrolled-keys=0
qm disk import 103 /var/lib/vz/template/iso/debian-13-genericcloud-amd64.qcow2 local-zfs
qm set 103 --scsi0 local-zfs:vm-103-disk-1,discard=on,iothread=1,ssd=1 --boot order=scsi0
qm disk resize 103 scsi0 40G
qm set 103 --ide2 local-zfs:cloudinit --ciuser jdreier \
  --sshkeys <(qm config 120 | sed -n "s/^sshkeys: //p" | python3 -c "import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read()))") \
  --ipconfig0 ip=10.0.3.5/9,gw=10.0.0.1 --nameserver 10.0.0.1
qm start 103'
```

Check `qm config 103` afterwards. The imported disk may get a different
`vm-103-disk-N` name. disko addresses the disk as
`scsi-0QEMU_QEMU_HARDDISK_drive-scsi0`, so it has to be attached as `scsi0`.

## 3. Install NixOS

```bash
cd ~/Projects/nix_dots_2
nix run github:nix-community/nixos-anywhere -- --flake .#datacron \
  --build-on remote --target-host jdreier@10.0.3.5
ssh root@192.168.0.10 'qm set 103 --delete ide2'   # cloud-init is done
```

Later changes go out the same way as pitdroid's, building on pitdroid since
holocron is aarch64:

```bash
nix run nixpkgs#nixos-rebuild -- switch --flake .#datacron \
  --target-host root@10.0.3.5 --build-host root@10.0.1.31
```

## 4. Check the empty server

```bash
ssh root@10.0.3.5 'systemctl is-active postgresql postgresql-db-owners postgresql-ssl-cert;
  sudo -u postgres psql -Atc "select version()";
  sudo -u postgres psql -Atc "select datname, pg_get_userbyid(datdba) from pg_database order by 1";
  sudo -u postgres psql -Atc "show ssl"'
```

Expect 31 databases (plus `postgres` and the templates) with the owners from
the table above, and `ssl = on`.

## 5. Copy roles' password hashes (no downtime)

The hashes go from server to server through a pipe and are never printed. The
new server accepts an md5 or scram hash given to `ALTER ROLE … PASSWORD` as-is.

```bash
# CT101: every role except authentik/paperless (CT111's win) and postgres.
ssh root@192.168.0.10 "pct exec 101 -- su postgres -c \"psql -XAt -c \\\"select format('ALTER ROLE %I PASSWORD %L;', rolname, rolpassword) from pg_authid where rolpassword is not null and rolname not in ('postgres','authentik','paperless') and rolname !~ '^pg_'\\\"\"" \
  | ssh root@10.0.3.5 'sudo -u postgres psql -X -q -v ON_ERROR_STOP=1'

# CT111: authentik, paperless, paperclip.
ssh root@192.168.0.10 "pct exec 111 -- su postgres -c \"psql -XAt -c \\\"select format('ALTER ROLE %I PASSWORD %L;', rolname, rolpassword) from pg_authid where rolpassword is not null and rolname in ('authentik','paperless','paperclip')\\\"\"" \
  | ssh root@10.0.3.5 'sudo -u postgres psql -X -q -v ON_ERROR_STOP=1'
```

Also check database-level grants and per-role settings on both old servers.
On 2026-11-05 there were no per-role settings. If `datacl` shows anything
non-null, reapply it by hand.

```sql
select datname, datacl from pg_database where datacl is not null;
select * from pg_db_role_setting;
```

## 6. Re-hash md5 roles to scram

For each role whose password is known, set it again on datacron. The server
then stores a scram hash. Read the secret from where the app keeps it and pass
it to psql without echoing it, e.g.

```bash
# example for sonarr: the password is in the pod's config.xml
PW=$(kubectl --context admin@media-cluster -n media exec deploy/sonarr -- \
  sed -n 's:.*<PostgresPassword>\(.*\)</PostgresPassword>.*:\1:p' /config/config.xml)
printf '%s' "$PW" | ssh root@10.0.3.5 \
  'sudo -u postgres psql -X -q -v ON_ERROR_STOP=1 -v pw="$(cat)" -c "ALTER ROLE sonarr PASSWORD :'"'"'pw'"'"'"'
unset PW
```

| Role | Where its password lives |
|---|---|
| sonarr, radarr | `/config/config.xml` in the pods (media-cluster) |
| umami | 1Password `umami-db-connection` |
| specmarshal | 1Password `specmarshal-db-connection` |
| paperless | Tower container `paperless-ngx`, `PAPERLESS_DBPASS` |
| terraform (or root) | `PGUSER`/`PGPASSWORD` exported by gitops_homelab_2_0's `secrets.env`, which OpenTofu's pg backend reads because `backend.hcl` carries no credentials. James confirms which role `PGUSER` names and does the re-hash himself from a shell that has sourced the file. Until then the `holocron` client entry uses `method = "md5"`; set it back to the default once the role has a scram hash |
| authentik, paperclip | already scram, nothing to do |
| hassio, n8n, keycloak_user, backstage, scanopy, root | dormant. Re-hash when the app comes back, or give its client `method = "md5"` |

Check what's left: `select rolname from pg_authid where rolpassword like 'md5%';`

## 7. Move the dormant databases (no downtime)

None of these had a session since CT101's restart on 2026-09-17, so they can
move any time. Dump with the source's `pg_dump -Fc` and restore as postgres,
which keeps every object's owner (the roles already exist):

```bash
mv_db () { # mv_db <ct> <source db> <target db>
  ssh root@192.168.0.10 "pct exec $1 -- su postgres -c 'pg_dump -Fc -d $2'" \
    | ssh root@10.0.3.5 "sudo -u postgres pg_restore -d $3 --exit-on-error"
}
for d in hass_db n8n keycloak keycloak_db scanopy backstage \
         backstage_plugin_{app,auth,catalog,kubernetes,permission,proxy,scaffolder,search,techdocs} \
         terraform_state terraform_kratix_cluster terraform_lenovo_cluster terraform_media_cluster root; do
  mv_db 101 $d $d
done
mv_db 101 authentik authentik_ct101
mv_db 101 paperless paperless_ct101
mv_db 111 paperclip paperclip
```

The terraform states are only written when someone runs OpenTofu. Don't run
tofu between this step and the CT101 cutover, or re-copy them during step 8.

Verify each with the row-count check in step 10.

## 8. Cutover A: everything that points at 10.0.3.1 (one window, ~15 min)

sonarr, radarr, umami and specmarshal all use `10.0.3.1`, and datacron takes
that address over. CT101 has to be down first, so these move together.

1. Stop the writers:
   ```bash
   kubectl --context admin@media-cluster -n media scale deploy/sonarr deploy/radarr --replicas=0
   kubectl --context admin@the-cluster -n umami scale deploy/umami --replicas=0
   kubectl --context admin@the-cluster -n specmarshal scale deploy/specmarshal --replicas=0
   ```
   Argo CD may scale them back. Pause auto-sync on those apps for the window.
2. Final copies: `mv_db 101 <db> <db>` for sonarr, sonarrlogs, radarr,
   radarrlogs, umami and specmarshal (about 600 MB, a few minutes). Re-copy the
   terraform_* databases if tofu ran since step 7. A database that already has
   data must be dropped and recreated first (`systemctl restart postgresql`
   recreates it via ensureDatabases, then `postgresql-db-owners` sets its owner).
3. Take CT101 off the address: `ssh root@192.168.0.10 'pct shutdown 101 && pct set 101 --onboot 0'`.
4. In `hosts/datacron/default.nix` add `"10.0.3.1"` (and `"10.0.3.24"` at cutover B) to `addresses`, keeping `"10.0.3.5"` first,, commit, push, and
   deploy. The SSH target is still `10.0.3.5` until the switch, then `10.0.3.1`.
5. Run step 10's row counts for the six databases.
6. Scale the four apps back to 1 and resume auto-sync. Check Sonarr/Radarr
   System → Status and the umami dashboard.

**Rollback:** scale the apps to 0, set `address = "10.0.3.5"` and deploy, then
`pct start 101`. CT101's data hasn't changed since it was stopped. Scale the
apps up again.

## 9. Cutover B: authentik and paperless (CT111)

authentik going down means SSO is down for the window.

1. Stop authentik server and worker (the-cluster, namespace `authentik`, scale
   to 0, auto-sync paused) and stop the Tower `paperless-ngx` container.
2. `mv_db 111 authentik authentik` and `mv_db 111 paperless paperless`.
3. Repoint:
   - authentik: the `postgres-host` field behind secret `authentik-secrets`
     (1Password) becomes `10.0.3.1`. The authentik network policy already
     allows `10.0.3.0/24` on 5432, so it needs no change.
   - paperless: Tower template `PAPERLESS_DBHOST` changes from `10.0.3.24` to
     `10.0.3.1`. Paperclip's `DATABASE_URL` too, if it ever runs again.
4. Start authentik and paperless. Log in through SSO and open a document.
5. `ssh root@192.168.0.10 'pct shutdown 111 && pct set 111 --onboot 0'`

**Rollback:** set the hosts back to `10.0.3.24`, `pct start 111`, restart the
apps.

## 10. Verify a copy

Exact row counts per table on both sides. Run this on the source (`pct exec`)
and on datacron, then diff:

```bash
COUNT='select format($$select %L, count(*) from %I.%I;$$, schemaname||$$.$$||relname, schemaname, relname) from pg_stat_user_tables order by 1'
# source
ssh root@192.168.0.10 "pct exec 101 -- su postgres -c \"psql -XAt -d sonarr -c '$COUNT' | psql -XAt -d sonarr\"" > /tmp/src.txt
# target
ssh root@10.0.3.5 "sudo -u postgres sh -c \"psql -XAt -d sonarr -c '$COUNT' | psql -XAt -d sonarr\"" > /tmp/dst.txt
diff /tmp/src.txt /tmp/dst.txt && echo identical
```

Run `ANALYZE` on each database after restoring. pg_restore doesn't carry
planner statistics, and Sonarr is slow until it has them.

## 11. Backups after the move

- `postgresqlBackup` dumps every database nightly at 02:15 to
  `/var/backup/postgresql`. The copy to Tower (`postgresql-backup-ship`) is
  switched off (`shipToTower = false` in `backup.nix`) since a vzdump to
  Tower's NFS export hung Tower on 2026-11-05. Nothing writes to Tower without
  James's OK; the off-box copy is going to be a nightly pull from holocron.
  When the ship is on, it copies them at 03:30
  to Tower under `backups/datacron/<date>/`, keeping 30 days. Check after the
  first night:
  `ssh root@10.0.0.12 'ls -la /mnt/user/data/backups/datacron/$(date +%F)'`.
- Proposed vzdump job (not created yet). Proxmox has no backup jobs today:
  ```bash
  ssh root@192.168.0.10 'pvesh create /cluster/backup --id pg-nightly --schedule "01:30" \
    --vmid 103,101,111 --storage local --mode snapshot --compress zstd \
    --prune-backups keep-daily=7,keep-weekly=4 --enabled 1'
  ```
  `local` is on the same host. To get these off the box, add Tower as Proxmox
  storage first, e.g. `pvesm add nfs tower-backups --server 10.0.0.12
  --export /mnt/user/data --content backup`, then use `--storage tower-backups`.
  Drop 101 and 111 from the job when they're deleted.

## 12. Retire the old servers

Leave CT101 and CT111 stopped with `onboot 0` for two weeks. Then take a last
vzdump of each and, with James's OK, `pct destroy`.

Loose ends to clear at the same time:

- `docs/terraform.md` in gitops_homelab_2_0 uses
  `postgres.integratn.tech`, which doesn't resolve. Either add a UniFi local DNS
  record `postgres.integratn.tech → 10.0.3.1` or change the doc to the address.
- The repo docs that say authentik uses `10.0.3.1` become true at cutover B.
- Once `select rolname from pg_authid where rolpassword like 'md5%'` is empty,
  no client entry needs `method = "md5"`.

## Moving to Postgres 19 later

The major version is pinned (`pkgs.postgresql_18`), so `nix flake update`
never moves it. To upgrade, follow the NixOS manual's "Upgrading" section for
PostgreSQL: build the new package's `upgrade-pg-cluster` script, stop
postgres, run `pg_upgrade` from `/var/lib/postgresql/18` to
`/var/lib/postgresql/19`, then change the pin. Take a pg_dump and a vzdump
first.
