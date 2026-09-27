#!/usr/bin/env bash
# Register self-hosted GitHub Actions runner instances on this host.
#
# Registration only: it mints a credential, which is why it is not part of
# `darwin-rebuild switch`. Supervision belongs to modules/darwin/github-runner.nix,
# which writes a LaunchDaemon for every name in its `instances` list — so this
# writes no plist. After registering, add the names there and switch.
#
# A runner's scope is fixed at registration and no workflow can widen it. The
# scope is a repository (owner/repo) or an organization (a bare org name, whose
# default runner group then hands the instance jobs from every repository in
# it). An instance takes one job at a time; register several to let a matrix
# fan out.
#
# An instance already registered to a different scope is moved: its launchd
# job is stopped, its registration removed from the old scope, and it is
# registered to the new one and started again. Do it while it is idle, since a
# job it is running is lost. One registered to this scope already is skipped.
#
# usage: scripts/register-runner.sh <owner/repo | org> <instance>...
#   e.g. scripts/register-runner.sh IntegratnIO specmarshal specmarshal-{2,3,4}
set -euo pipefail

runner_version="2.337.0"   # what the instances already installed here run
labels="nix"               # self-hosted, macOS and ARM64 are added automatically
runner_user="ghrunner"
base="/Users/${runner_user}/actions-runner"

if [ "$#" -lt 2 ]; then
  sed -n '/^# usage:/,/^#   e.g./p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
  exit 64
fi

scope="$1"
shift

# api_base is where GitHub keeps a scope's runners: an organization's when the
# scope has no slash, a repository's when it has one.
api_base() {
  case "$1" in
    */*) echo "repos/$1" ;;
    *) echo "orgs/$1" ;;
  esac
}

tarball="actions-runner-osx-arm64-${runner_version}.tar.gz"
cached="$(mktemp -d)/${tarball}"
trap 'rm -rf -- "$(dirname -- "$cached")"' EXIT

echo "==> Fetching runner ${runner_version}"
curl -fsSL -o "$cached" \
  "https://github.com/actions/runner/releases/download/v${runner_version}/${tarball}"

for instance in "$@"; do
  dir="${base}/${instance}"

  label="io.integratn.${runner_user}.${instance}"
  plist="/Library/LaunchDaemons/${label}.plist"
  moved=""

  if sudo test -f "${dir}/.runner"; then
    current="$(sudo grep -o '"gitHubUrl": *"[^"]*"' "${dir}/.runner" | sed 's/.*"\(https[^"]*\)"$/\1/')"
    if [ "$current" = "https://github.com/${scope}" ]; then
      echo "==> ${instance} is already registered to ${scope}, skipping"
      continue
    fi

    old_scope="${current#https://github.com/}"
    echo "==> Moving ${instance} from ${old_scope} to ${scope}"
    sudo launchctl bootout "system/${label}" 2>/dev/null || true
    sudo env RUNNER_ALLOW_RUNASROOT=1 "HOME=/Users/${runner_user}" "${dir}/config.sh" remove \
      --token "$(gh api -X POST "$(api_base "$old_scope")/actions/runners/remove-token" -q .token)"
    moved=1
  else
    echo "==> Unpacking ${instance}"
    sudo mkdir -p "$dir" "${dir}/_diag"
    sudo tar xzf "$cached" -C "$dir"
  fi

  # config.sh refuses to run as root, and `sudo -u ghrunner` is not available
  # either: the account is hidden and its shell is /usr/bin/false. So configure
  # as root with the documented waiver, then hand the tree over so the daemon
  # owns its own credentials. Each instance takes a fresh token; they expire.
  echo "==> Registering ${instance} as mac-studio-${instance}"
  sudo env RUNNER_ALLOW_RUNASROOT=1 "HOME=/Users/${runner_user}" "${dir}/config.sh" \
    --url "https://github.com/${scope}" \
    --token "$(gh api -X POST "$(api_base "$scope")/actions/runners/registration-token" -q .token)" \
    --name "mac-studio-${instance}" \
    --labels "$labels" \
    --work _work \
    --unattended --replace

  sudo chown -R "${runner_user}:staff" "$dir"

  # A moved instance already has its plist; start it again rather than waiting
  # for a switch that has nothing to change.
  if [ -n "$moved" ] && [ -f "$plist" ]; then
    sudo launchctl bootstrap system "$plist"
  fi
done

cat >&2 <<EOF

==> Registered. A new instance stays offline until launchd is told about it: add
    it to \`instances\` in modules/darwin/github-runner.nix, then

      sudo darwin-rebuild switch --flake .#mac-studio

EOF

gh api "$(api_base "$scope")/actions/runners" \
  -q '.runners[] | "\(.name)\t\(.status)\tlabels=\([.labels[].name]|join(","))"'
