#!/usr/bin/env bash
# Build probedroid on the Mac's linux-builder and deploy it over the tailnet,
# with an automatic rollback: before activating, the Pi arms a timer that
# switches back to the running generation. The script only disarms it after a
# fresh SSH connection reaches the new generation, so a deploy that breaks
# networking or Tailscale undoes itself instead of needing a trip to Mom's.
#
#   scripts/deploy-probedroid.sh [switch|test] [--reboot]
#
#   switch   activate now and make it the boot default (default)
#   test     activate now without touching the boot default
#   --reboot reboot after a confirmed switch and wait for SSH to come back
#
# PROBEDROID_HOST overrides the target (default: the tailnet name "probedroid").
# MOM_PI_ROLLBACK_SECS sets the rollback window (default 180).

# Remote commands deliberately interpolate local values (store paths).
# shellcheck disable=SC2029
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo="${script_dir}/.."
host="${PROBEDROID_HOST:-probedroid}"
window="${MOM_PI_ROLLBACK_SECS:-180}"

action=switch
reboot=false
for arg in "$@"; do
  case "$arg" in
    switch | test) action="$arg" ;;
    --reboot) reboot=true ;;
    *)
      sed -n '2,15p' "$0" >&2
      exit 2
      ;;
  esac
done
if $reboot && [[ "$action" == test ]]; then
  echo "error: --reboot after test would boot the old generation" >&2
  exit 2
fi

say() { printf '\033[36m==>\033[0m %s\n' "$*"; }
remote() { ssh -o ConnectTimeout=8 -o BatchMode=yes "root@${host}" "$@"; }

say "Building on the linux-builder"
out=$(nix build "${repo}#nixosConfigurations.probedroid.config.system.build.toplevel" \
  --no-link --print-out-paths)
echo "$out"

say "Copying closure to ${host}"
# The builder's paths are unsigned, hence --no-check-sigs.
nix copy --no-check-sigs --to "ssh-ng://root@${host}" "$out"

old=$(remote readlink -f /run/current-system)
if [[ "$old" == "$out" ]]; then
  echo "ok: ${host} already runs ${out##*/}"
  exit 0
fi

say "Arming rollback to ${old##*/} in ${window}s"
remote "systemctl stop deploy-rollback.timer 2>/dev/null; systemctl reset-failed deploy-rollback.service 2>/dev/null; \
  systemd-run --unit=deploy-rollback --on-active=${window} /bin/sh -c \
  '${old}/sw/bin/nix-env -p /nix/var/nix/profiles/system --set ${old} && ${old}/bin/switch-to-configuration switch'"

say "Activating (${action})"
# Run it as a transient unit so it finishes even if the switch restarts
# tailscaled or the network and drops this SSH session. Transient units get a
# bare PATH, so every command is absolute.
if [[ "$action" == switch ]]; then
  activate="${out}/sw/bin/nix-env -p /nix/var/nix/profiles/system --set ${out} && ${out}/bin/switch-to-configuration switch"
else
  activate="${out}/bin/switch-to-configuration test"
fi
status=0
remote "systemd-run --unit=deploy-activate-$(date +%s) --collect --wait --pipe /bin/sh -c '${activate}'" || status=$?
if ((status != 0 && status != 255)); then
  # The session survived and reported a failure: roll back now instead of
  # waiting out the timer.
  echo "error: activation failed (exit ${status}); rolling back to ${old##*/}" >&2
  remote "systemctl stop deploy-rollback.timer; systemctl start deploy-rollback.service"
  exit 1
elif ((status == 255)); then
  echo "warning: lost the SSH session during activation; checking over a fresh connection" >&2
fi

say "Confirming over a fresh connection"
deadline=$((SECONDS + window - 20))
confirmed=false
while ((SECONDS < deadline)); do
  if current=$(remote readlink -f /run/current-system 2>/dev/null) && [[ "$current" == "$out" ]]; then
    remote "systemctl stop deploy-rollback.timer"
    confirmed=true
    break
  fi
  sleep 5
done
if ! $confirmed; then
  echo "error: could not confirm ${out##*/}; ${host} rolls back to ${old##*/} when the timer fires" >&2
  exit 1
fi
echo "ok: ${host} runs ${out##*/}; rollback disarmed"

if [[ "$action" == switch ]]; then
  say "Verifying the firmware boot entry"
  if remote "grep -qF 'init=${out}/init' /boot/firmware/nixos/default/cmdline.txt"; then
    echo "ok: next boot uses ${out##*/}"
  else
    echo "error: /boot/firmware/nixos/default/cmdline.txt does not point at the new generation" >&2
    remote "findmnt /boot/firmware; grep -o 'init=[^ ]*' /boot/firmware/nixos/default/cmdline.txt" >&2 || true
    exit 1
  fi
fi

if $reboot; then
  say "Rebooting ${host}"
  remote "systemctl reboot" || true
  sleep 20
  for _ in $(seq 1 36); do
    if current=$(remote readlink -f /run/current-system 2>/dev/null); then
      if [[ "$current" == "$out" ]]; then
        echo "ok: ${host} is up on the new generation"
        exit 0
      fi
      echo "error: ${host} came back on ${current##*/}, expected ${out##*/}" >&2
      exit 1
    fi
    sleep 5
  done
  echo "error: ${host} did not come back within ~3 minutes" >&2
  exit 1
fi
