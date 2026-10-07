#!/usr/bin/env bash
# Rebuild the laptop from the Mac over SSH. The Mac has no x86_64 builder, so
# only the flake's source is copied over and the laptop builds itself.
#
#   scripts/deploy-carbonite.sh [switch|boot|test]
#
#   switch   activate now and make it the boot default (default)
#   boot     only make it the boot default; takes effect on next reboot
#   test     activate now without touching the boot default
#
# CARBONITE_HOST overrides the target (default: the tailnet name "carbonite",
# the only interface the laptop accepts SSH on).

# Remote commands deliberately interpolate local values (the store path).
# shellcheck disable=SC2029
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo="${script_dir}/.."
host="${CARBONITE_HOST:-carbonite}"

action="${1:-switch}"
case "$action" in
  switch | boot | test) ;;
  *)
    sed -n '2,12p' "$0" >&2
    exit 2
    ;;
esac

say() { printf '\033[36m==>\033[0m %s\n' "$*"; }

say "Copying the flake and its inputs to ${host}"
# The last "path" in the JSON is the flake's own source; the inputs precede it.
src=$(nix flake archive --json --to "ssh-ng://root@${host}" "$repo" | sed 's/.*"path":"\([^"]*\)"}$/\1/')
echo "$src"

say "Building and activating on ${host} (${action})"
ssh "root@${host}" "nixos-rebuild ${action} --flake ${src}#carbonite"

if [[ "$action" != boot ]]; then
  echo "ok: ${host} is running $(ssh "root@${host}" readlink /run/current-system | sed 's|.*/||')"
fi
