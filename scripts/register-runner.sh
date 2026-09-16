#!/usr/bin/env bash
# Register self-hosted GitHub Actions runner instances on this host.
#
# Registration only: it mints a credential, which is why it is not part of
# `darwin-rebuild switch`. Supervision belongs to modules/darwin/github-runner.nix,
# which writes a LaunchDaemon for every name in its `instances` list — so this
# writes no plist. After registering, add the names there and switch.
#
# A runner's scope is fixed at registration and no workflow can widen it, so
# each repository that wants this host needs instances of its own. An instance
# takes one job at a time; register several of the same repository to let a
# matrix fan out.
#
# usage: scripts/register-runner.sh <owner/repo> <instance>...
#   e.g. scripts/register-runner.sh IntegratnIO/specmarshal specmarshal-{2,3,4}
set -euo pipefail

runner_version="2.337.0"   # what the instances already installed here run
labels="nix"               # self-hosted, macOS and ARM64 are added automatically
runner_user="ghrunner"
base="/Users/${runner_user}/actions-runner"

if [ "$#" -lt 2 ]; then
  sed -n '/^# usage:/,/^#   e.g./p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
  exit 64
fi

repo="$1"
shift

tarball="actions-runner-osx-arm64-${runner_version}.tar.gz"
cached="$(mktemp -d)/${tarball}"
trap 'rm -rf -- "$(dirname -- "$cached")"' EXIT

echo "==> Fetching runner ${runner_version}"
curl -fsSL -o "$cached" \
  "https://github.com/actions/runner/releases/download/v${runner_version}/${tarball}"

for instance in "$@"; do
  dir="${base}/${instance}"

  if [ -f "${dir}/.runner" ]; then
    echo "==> ${instance} is already registered, skipping"
    continue
  fi

  echo "==> Unpacking ${instance}"
  sudo mkdir -p "$dir" "${dir}/_diag"
  sudo tar xzf "$cached" -C "$dir"

  # config.sh refuses to run as root, and `sudo -u ghrunner` is not available
  # either: the account is hidden and its shell is /usr/bin/false. So configure
  # as root with the documented waiver, then hand the tree over so the daemon
  # owns its own credentials. Each instance takes a fresh token; they expire.
  echo "==> Registering ${instance} as mac-studio-${instance}"
  sudo env RUNNER_ALLOW_RUNASROOT=1 "HOME=/Users/${runner_user}" "${dir}/config.sh" \
    --url "https://github.com/${repo}" \
    --token "$(gh api -X POST "repos/${repo}/actions/runners/registration-token" -q .token)" \
    --name "mac-studio-${instance}" \
    --labels "$labels" \
    --work _work \
    --unattended --replace

  sudo chown -R "${runner_user}:staff" "$dir"
done

cat >&2 <<EOF

==> Registered. They stay offline until launchd is told about them: add them to
    \`instances\` in modules/darwin/github-runner.nix, then

      sudo darwin-rebuild switch --flake .#mac-studio

EOF

gh api "repos/${repo}/actions/runners" \
  -q '.runners[] | "\(.name)\t\(.status)\tlabels=\([.labels[].name]|join(","))"'
