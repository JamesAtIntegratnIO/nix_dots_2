#!/usr/bin/env bash
# Build the PocketTerm35 system on the Mac's linux-builder and deploy it over
# SSH (no reflash). Checks afterwards that the firmware boot entry really points
# at the new generation -- /boot/firmware once silently missed every install.
#
#   scripts/deploy-pocketterm.sh [switch|boot|test] [--reboot]
#
#   switch   activate now and make it the boot default (default)
#   boot     only make it the boot default; takes effect on next reboot
#   test     activate now without touching the boot default
#   --reboot reboot afterwards and wait for SSH to come back
#
# POCKETTERM_HOST overrides the target (default: the tailnet name "pocketterm").

# Remote commands deliberately interpolate local values (the store path).
# shellcheck disable=SC2029
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo="${script_dir}/.."
host="${POCKETTERM_HOST:-pocketterm}"

action=switch
reboot=false
for arg in "$@"; do
  case "$arg" in
    switch | boot | test) action="$arg" ;;
    --reboot) reboot=true ;;
    *)
      sed -n '2,13p' "$0" >&2
      exit 2
      ;;
  esac
done

say() { printf '\033[36m==>\033[0m %s\n' "$*"; }

say "Building on the linux-builder"
out=$(nix build "${repo}#nixosConfigurations.pocketterm.config.system.build.toplevel" \
  --no-link --print-out-paths)
echo "$out"

# A live switch restarts systemd-udevd, which leaves a running RetroArch
# without input until it's restarted.
if [[ "$action" != boot ]] && ssh "jdreier@${host}" pgrep -f 'retroarch-with-cores.*[-]L' >/dev/null; then
  echo "warning: RetroArch is running and will lose input after the switch (restart it)" >&2
fi

say "Copying closure to ${host}"
# root, because jdreier isn't a trusted Nix user on the device; the builder's
# paths are unsigned, hence --no-check-sigs.
nix copy --no-check-sigs --to "ssh-ng://root@${host}" "$out"

say "Activating (${action})"
if [[ "$action" == test ]]; then
  ssh "root@${host}" "${out}/bin/switch-to-configuration test"
else
  ssh "root@${host}" "nix-env -p /nix/var/nix/profiles/system --set ${out} \
    && ${out}/bin/switch-to-configuration ${action}"

  say "Verifying the firmware boot entry"
  if ssh "root@${host}" "grep -qF 'init=${out}/init' /boot/firmware/nixos/default/cmdline.txt"; then
    echo "ok: next boot uses ${out##*/}"
  else
    echo "error: /boot/firmware/nixos/default/cmdline.txt does not point at the new generation" >&2
    ssh "root@${host}" "findmnt /boot/firmware; grep -o 'init=[^ ]*' /boot/firmware/nixos/default/cmdline.txt" >&2 || true
    exit 1
  fi
fi

if $reboot; then
  say "Rebooting ${host}"
  ssh "root@${host}" "systemctl reboot" || true
  sleep 20
  for _ in $(seq 1 30); do
    if current=$(ssh -o ConnectTimeout=4 -o BatchMode=yes "root@${host}" readlink /run/current-system 2>/dev/null); then
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
