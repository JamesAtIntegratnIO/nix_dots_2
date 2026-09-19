{ pkgs, lib, username, ... }:
let
  logDir = "/Users/${username}/Library/Logs/colima";

  # VM sizing for the Linux guest that hosts the docker daemon.
  cpus = "12";
  memory = "32";
  disk = "100";

  # Nothing else prunes colima's daemon, and everything on this machine shares
  # it: the specmarshal self-hosted runners (through the ghrunner socket bridge
  # in github-runner.nix), local specmarshal runs, and the kind cluster, which
  # turns off kubelet image GC and so cannot protect itself. CI loads a set of
  # per-commit image tags on every build and never removes them, and a job that
  # is cancelled or killed leaves its buildkit builder running with a ~1.2 GB
  # state volume. On 2026-09-19 that filled the VM's 99 GB data disk to 98% and
  # a clone died on ENOSPC; leaked builders have also exhausted the VM's inotify
  # instances before. specmarshal cleans up after itself in-workflow, but a
  # killed job skips that, so this is the backstop.
  #
  # It deliberately never runs `docker volume prune`: the kind node and
  # specmarshal's credential volume (specmarshal-claude-config) are named
  # volumes that look unused whenever their containers are stopped.
  dockerPrune = pkgs.writeShellScript "docker-prune" ''
    set -u
    # colima ssh shells out to limactl and the system ssh.
    export PATH=${lib.makeBinPath [ pkgs.docker pkgs.colima pkgs.coreutils ]}:/usr/bin:/bin:/usr/sbin:/sbin
    # The daemon's own socket, whatever the current docker context says.
    export DOCKER_HOST=unix:///Users/${username}/.colima/default/docker.sock

    # Measured inside the VM: `docker system df` only sees what docker
    # accounts for, not the disk that actually runs out.
    usage() {
      colima ssh -- df -h /mnt/lima-colima </dev/null || docker system df
    }

    echo "=== docker prune $(date -u +%FT%TZ)"
    if ! docker info >/dev/null 2>&1; then
      echo "docker daemon unreachable at $DOCKER_HOST; is colima running?"
      exit 1
    fi
    usage

    # Stale buildkit builders. A running CI job owns its builder, and no job
    # runs longer than 90 minutes, so anything created over 6 hours ago was
    # left behind by a job that never got to clean up.
    cutoff=$(( $(date +%s) - 6 * 3600 ))
    docker ps -a --filter name=buildx_buildkit_builder- --format '{{.Names}}' |
      while read -r name; do
        created=$(docker inspect -f '{{.Created}}' "$name") || continue
        # Created is RFC 3339 UTC with nanoseconds; GNU date reads it as-is.
        [ "$(date -d "$created" +%s)" -lt "$cutoff" ] || continue
        echo "removing stale builder $name (created $created)"
        docker rm -f -v "$name" >/dev/null
        # The state volume is named, so `rm -v` leaves it behind.
        docker volume rm "''${name}_state" >/dev/null 2>&1 || true
      done

    docker image prune -a -f --filter until=72h
    # --reserved-space is docker 29's name for the old --keep-storage.
    docker builder prune -f --reserved-space 10GB
    docker container prune -f --filter until=72h

    usage
  '';
in
{
  # Keep the colima log directory writable for the launchd user agent.
  system.activationScripts.colimaDirs.text = ''
    /bin/mkdir -p "${logDir}"
    /usr/sbin/chown -R ${username}:staff "${logDir}"
  '';

  # Colima runs the Linux VM the docker daemon lives in — nixpkgs' docker on
  # darwin is client-only, so without this there is nothing to connect to.
  # `--foreground` keeps the process attached so launchd can supervise it
  # instead of the usual detached background VM.
  launchd.user.agents.colima = {
    serviceConfig = {
      Label = "org.nixos.colima";
      ProgramArguments = [
        "${pkgs.colima}/bin/colima" "start"
        "--foreground"
        "--cpu" cpus
        "--memory" memory
        "--disk" disk
        # amd64 containers run under Rosetta, not colima's qemu 7.0, which
        # crashes Go 1.26 binaries and Chromium. The workstation's runner builds
        # and smoke-tests specmarshal's amd64 images this way.
        "--vm-type" "vz"
        "--vz-rosetta"
      ];
      EnvironmentVariables = {
        HOME = "/Users/${username}";
        # colima shells out to limactl, which needs the system ssh.
        PATH = lib.concatStringsSep ":" [
          "/usr/bin"
          "/bin"
          "/usr/sbin"
          "/sbin"
        ];
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/colima.log";
      StandardErrorPath = "${logDir}/colima.err";
    };
  };

  # A user agent for the colima owner rather than a daemon as ghrunner: only
  # this user can `colima ssh` into the VM to measure the real disk, and the
  # daemon itself only exists while this user's colima agent runs, so a job
  # that runs when they are logged out would have nothing to prune.
  #
  # `command`, not ProgramArguments, so nix-darwin wraps it in
  # `wait4path /nix/store`; see the docker-socket bridge in github-runner.nix.
  launchd.user.agents.docker-prune = {
    command = "${dockerPrune}";
    serviceConfig = {
      Label = "io.integratn.docker-prune";
      StartCalendarInterval = [ { Hour = 4; Minute = 0; } ];
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "${logDir}/docker-prune.log";
      StandardErrorPath = "${logDir}/docker-prune.log";
    };
  };
}
