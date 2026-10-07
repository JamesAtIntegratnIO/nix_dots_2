{ pkgs, lib, ... }:
let
  runnerUser = "ghrunner";

  # Scope is fixed at registration and one instance takes one job at a time.
  # The specmarshal instances are registered to the IntegratnIO organization
  # rather than to one repository, so the org's default runner group hands them
  # jobs from every IntegratnIO repository — the core, specmarshal-registry and
  # specmarshal-pro — without an instance per repository. They keep their names
  # so their state directories stay put. runwright is a personal-account
  # repository and cannot be served by an org runner, so it keeps its own.
  #
  # specmarshal has eight rather than the darwin module's four. This host is
  # x86_64, so it takes the image matrix's amd64 leg natively instead of the
  # Mac's Rosetta emulation, and that leg fans out to five builds: four
  # instances leave the fifth queueing behind the others. Eight covers one
  # wave with room for a second pull request's, and matches the VM's eight
  # vCPU against its 24G of memory.
  specmarshalInstances = 8;

  # The verification gates of the core, pro and the registry run here rather
  # than on the Mac, which also runs the service and its sandboxes and timed
  # the gates' tests out under that load. A gate fills the machine by itself,
  # so only these instances carry the `gate` label the gate jobs ask for, and
  # GitHub queues a third gate behind them rather than starting it beside them
  # (a workflow concurrency group cannot do this: it cancels what is waiting).
  # They still take any other Linux job when no gate is waiting.
  gateInstances = [ "specmarshal-7" "specmarshal-8" ];

  instances = {
    runwright = "JamesAtIntegratnIO/runwright";
  } // builtins.listToAttrs (
    map
      (n: {
        name = if n == 1 then "specmarshal" else "specmarshal-${toString n}";
        value = "IntegratnIO";
      })
      (lib.range 1 specmarshalInstances)
  );

  # The registration token each instance consumes on first start. It expires
  # within the hour, but the module only needs it once: the credential it mints
  # lives in the instance's state directory afterwards. scripts/register-runner-nixos.sh
  # writes these.
  tokenDir = "/var/lib/github-runner-tokens";

  # Where each instance checks out and builds. The module's default is its
  # RuntimeDirectory under /run, a tmpfs capped at a quarter of RAM (5.9G here)
  # and shared by every instance; eight checkouts with their node_modules filled
  # it and jobs died with "No space left on device". This puts them on the disk.
  # HOME is the work dir too, so toolchain caches land here as well. Changing it
  # re-registers every instance: run scripts/register-runner-nixos.sh after.
  workRoot = "/var/lib/github-runner-work";

  # Each runner service has PrivateTmp, so a job's /tmp is a directory of its
  # own under the host's /tmp that lasts as long as the service does, and the
  # services run for weeks. `nix develop -c` leaves a nix-shell.XXXXXX there on
  # every job, with whatever the gate wrote under TMPDIR, and the tests leave
  # their own. The same leak filled the Mac's disk on 2026-10-07 (the darwin
  # tmp-sweep module); here it is slower only because a rebuild that restarts
  # the runners empties it.
  #
  # No job lasts longer than 90 minutes, so anything at the top of a runner's
  # /tmp that has sat for six hours belongs to a job that is over.
  tmpSweep = pkgs.writeShellScript "runner-tmp-sweep" ''
    set -u
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.findutils ]}
    echo "=== runner tmp sweep $(date -u +%FT%TZ)"
    df -h /tmp | tail -1
    for private in /tmp/systemd-private-*-github-runner-*/tmp; do
      [ -d "$private" ] || continue
      count=$(find "$private" -mindepth 1 -maxdepth 1 -mmin +360 -print | wc -l)
      find "$private" -mindepth 1 -maxdepth 1 -mmin +360 -exec rm -rf -- {} +
      echo "$count removed from $private"
    done
    df -h /tmp | tail -1
  '';

  runner = instance: repo: {
    name = instance;
    value = {
      enable = true;
      url = "https://github.com/${repo}";
      name = "ghrunner-${instance}";
      tokenFile = "${tokenDir}/${instance}";
      extraLabels = [ "nix" ] ++ lib.optional (builtins.elem instance gateInstances) "gate";
      replace = true;
      workDir = "${workRoot}/${instance}";
      user = runnerUser;
      group = runnerUser;
      # What a job's steps reach for outside a dev shell. The first six are what
      # the image jobs need. jq, perl (for shasum) and gh came with the jobs
      # that moved here from the Mac, where Homebrew and the system supplied
      # them: the workflows are written once and run on either host, so this
      # host carries the tools rather than each workflow working around them.
      extraPackages = with pkgs; [
        docker
        docker-buildx
        nix
        gnutar
        gzip
        curl
        jq
        perl
        gh
      ];
      # One docker config per instance, so concurrent jobs don't share buildx
      # state or registry logins. See the darwin module for the failure this
      # avoids.
      extraEnvironment.DOCKER_CONFIG = "/var/lib/github-runner/${instance}/.docker";
    };
  };
in
{
  # Actions that provision a toolchain — actions/setup-node above all — download
  # a generic linux-x86_64 tarball and run it. Those binaries expect an
  # interpreter at /lib64/ld-linux-x86-64.so.2, which NixOS does not have, so
  # every such step dies with "Could not start dynamically linked executable".
  # nix-ld supplies the interpreter and the libraries the tarballs link against,
  # which keeps the workflows arch-agnostic: they run the same steps here as on
  # the Mac rather than branching on which host took the job.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      openssl

      # What the Chromium that Playwright downloads links against. The
      # verification gates run their Storybook stories in it, and on this host
      # it starts through nix-ld like any other generic binary; without these
      # it dies on libglib-2.0.so.0 before it opens a page.
      glib
      nspr
      nss
      atk
      at-spi2-atk
      at-spi2-core
      dbus
      expat
      cups
      pango
      cairo
      libdrm
      libgbm
      libxkbcommon
      alsa-lib
      systemd
      xorg.libX11
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libxcb
    ];
  };

  # The module's default prune is a weekly `docker system prune -f`, which
  # removes only dangling images and leaves every per-commit tag CI loads and
  # all the build cache that is not dangling: 773 images and 48 GB of cache on
  # 2026-10-07, 66 GB of a 125 GB disk. Daily, and everything unused for three
  # days, the same window the Mac's prune keeps (modules/darwin/docker.nix).
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "daily";
      flags = [
        "--all"
        "--filter"
        "until=72h"
      ];
    };
  };

  # Three days of cache from eight runners is still most of the disk, so the
  # cache is also held to a size. --reserved-space is docker 29's name for the
  # old --keep-storage.
  systemd.services.docker-prune.serviceConfig.ExecStartPost =
    "${pkgs.docker}/bin/docker builder prune -f --reserved-space 10GB";

  systemd.services.runner-tmp-sweep = {
    description = "Remove what finished jobs left in the runners' private /tmp";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = tmpSweep;
    };
  };
  systemd.timers.runner-tmp-sweep = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };

  users.groups.${runnerUser} = { };
  users.users.${runnerUser} = {
    isSystemUser = true;
    group = runnerUser;
    extraGroups = [ "docker" ];
    description = "GitHub Actions self-hosted runner";
  };

  nix.settings.trusted-users = [ runnerUser ];

  systemd.tmpfiles.rules = [
    "d ${tokenDir} 0700 root root -"
  ]
  ++ map (instance: "d ${workRoot}/${instance} 0750 ${runnerUser} ${runnerUser} -") (
    builtins.attrNames instances
  );

  services.github-runners = lib.mapAttrs' runner instances;
}
