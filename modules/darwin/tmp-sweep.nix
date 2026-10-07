{ pkgs, lib, username, ... }:
let
  # The account the self-hosted runners run as (github-runner.nix).
  runnerUser = "ghrunner";
  runnerHome = "/Users/${runnerUser}";

  # `nix develop -c <command>` makes a /tmp/nix-shell.XXXXXX, points TMPDIR at
  # it and execs the command, so nothing is left to remove the directory when
  # the command exits. Whatever the command wrote under TMPDIR stays with it: a
  # specmarshal gate leaves a few hundred megabytes of test homes and package
  # stores per run. Every CI job on this machine and every local gate goes
  # through `nix develop`, and macOS no longer ages /private/tmp itself. On
  # 2026-10-07 the runners' 3,735 leftovers held about 150 GB and the disk was
  # full.
  #
  # Each account sweeps only its own directories, so this needs no root and
  # cannot remove another account's work. The argument is how many hours old a
  # directory must be. A directory a live process still names as its TMPDIR is
  # kept however old it is, because an interactive `nix develop` can stay open
  # for days.
  tmpSweep = pkgs.writeShellScript "tmp-sweep" ''
    set -u
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.findutils pkgs.gnugrep ]}:/usr/bin:/bin
    hours=$1
    me=$(id -un)

    echo "=== tmp sweep $(date -u +%FT%TZ) as $me, older than ''${hours}h"
    df -h /private/tmp | tail -1

    # macOS ps prints a process's environment after its command with -E, and
    # only for the caller's own processes, which are the ones that matter here.
    live=$(/bin/ps -Eww -U "$(id -u)" -o command= | grep -o 'nix-shell\.[A-Za-z0-9]\+' | sort -u)

    find /private/tmp -maxdepth 1 -user "$me" -type d \
      \( -name 'nix-shell.*' -o -name 'nix-develop-*' \) \
      -mmin "+$(( hours * 60 ))" -print0 |
      while IFS= read -r -d "" dir; do
        name=''${dir##*/}
        case $name in
          nix-shell.*)
            if printf '%s\n' "$live" | grep -qxF "$name"; then
              echo "keeping $name: a live process has it as TMPDIR"
              continue
            fi
            ;;
          nix-develop-*)
            # nix-develop-<pid>-<n>, made by the nix process that owns it.
            pid=''${name#nix-develop-}
            pid=''${pid%%-*}
            if kill -0 "$pid" 2>/dev/null; then
              continue
            fi
            ;;
        esac
        # A Go module cache or a nix store copy under TMPDIR is read-only, and
        # rm cannot empty a directory it cannot write to.
        rm -rf "$dir" 2>/dev/null || { chmod -R u+w "$dir" 2>/dev/null; rm -rf "$dir"; }
        echo "removed $name"
      done | { grep -c '^removed ' || true; } | sed 's/$/ directories removed/'

    df -h /private/tmp | tail -1
  '';
in
{
  # `command`, not ProgramArguments, so nix-darwin wraps each in
  # `wait4path /nix/store`; see the docker-socket bridge in github-runner.nix.

  # No job on a runner lasts longer than 90 minutes (docker.nix), so a runner
  # directory untouched for six hours belongs to a job that is over. Hourly,
  # because the runners refill it at about 12 GB a day.
  launchd.daemons.tmp-sweep-runner = {
    command = "${tmpSweep} 6";
    serviceConfig = {
      Label = "io.integratn.${runnerUser}.tmp-sweep";
      UserName = runnerUser;
      StartInterval = 3600;
      RunAtLoad = true;
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "${runnerHome}/actions-runner/tmp-sweep.log";
      StandardErrorPath = "${runnerHome}/actions-runner/tmp-sweep.log";
    };
  };

  # The same leak from this account's own gates and agent sessions, slower. A
  # day's grace, since a local session can be mid-task for hours.
  launchd.user.agents.tmp-sweep = {
    command = "${tmpSweep} 24";
    serviceConfig = {
      Label = "io.integratn.tmp-sweep";
      StartCalendarInterval = [ { Hour = 4; Minute = 30; } ];
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "/Users/${username}/Library/Logs/tmp-sweep.log";
      StandardErrorPath = "/Users/${username}/Library/Logs/tmp-sweep.log";
    };
  };
}
