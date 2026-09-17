#!/usr/bin/env bash
# Hand registration tokens to the runner instances on a NixOS host.
#
# The nixos counterpart of register-runner.sh. It differs because
# services.github-runners does the registering itself: it only needs a token
# file per instance, consumed on first start. So this mints a token for every
# instance the host's configuration declares and drops it where that instance's
# unit expects it, rather than unpacking and configuring anything.
#
# Registration is still not part of `nixos-rebuild switch`, for the same reason
# as on darwin: it mints a credential. A token expires within the hour, but the
# instance only needs it once — the credential it exchanges the token for lives
# in the unit's StateDirectory afterwards.
#
# usage: scripts/register-runner-nixos.sh [host]
#   e.g. scripts/register-runner-nixos.sh root@192.168.0.31
set -euo pipefail

host="${1:-root@192.168.0.31}"
flake_host="ghrunner"
token_dir="/var/lib/github-runner-tokens"

# The instances and their repositories come from the configuration itself, so
# this cannot drift from modules/nixos/github-runner.nix.
echo "==> Reading instances from .#nixosConfigurations.${flake_host}"
# mapfile would be tidier but this also has to run from the macOS bash 3.2.
instances=()
while IFS= read -r line; do
  [ -n "$line" ] && instances+=("$line")
done < <(
  nix eval --json ".#nixosConfigurations.${flake_host}.config.services.github-runners" \
    --apply 'rs: builtins.concatStringsSep "\n" (
      builtins.attrValues (builtins.mapAttrs (n: v: n + " " + v.url) rs)
    )' | sed 's/^"//; s/"$//; s/\\n/\
/g'
)

if [ "${#instances[@]}" -eq 0 ]; then
  echo "no runner instances declared" >&2
  exit 1
fi

for entry in "${instances[@]}"; do
  instance="${entry%% *}"
  url="${entry##* }"
  repo="${url#https://github.com/}"

  echo "==> Minting a registration token for ${instance} (${repo})"
  token="$(gh api -X POST "repos/${repo}/actions/runners/registration-token" -q .token)"

  # The token file is the credential; 0600 and root-owned, in a directory the
  # module's tmpfiles rule already created as 0700.
  ssh "$host" "install -m 0600 /dev/stdin ${token_dir}/${instance}" <<<"$token"

  echo "==> Starting github-runner-${instance}"
  ssh "$host" "systemctl restart github-runner-${instance}.service"
done

echo
echo "==> Runners now known to GitHub:"
for entry in "${instances[@]}"; do
  url="${entry##* }"
  repo="${url#https://github.com/}"
  gh api "repos/${repo}/actions/runners" \
    -q '.runners[] | "\(.name)\t\(.status)\tlabels=\([.labels[].name]|join(","))"'
done | sort -u
