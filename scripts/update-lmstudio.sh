#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
overlay_file="${script_dir}/../modules/darwin/overlays.nix"

url=$(curl -fILs -o /dev/null -w '%{url_effective}' "https://lmstudio.ai/download/latest/darwin/arm64")
version="$(basename "$url" | sed -E 's/^LM-Studio-(.*)-arm64\.dmg$/\1/')"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?$ ]]; then
  echo "Unexpected LM Studio download URL: $url" >&2
  exit 1
fi

hash=$(nix --extra-experimental-features nix-command hash convert --hash-algo sha256 "$(nix-prefetch-url "$url")")

# Environment variables keep fetched text out of the Perl program itself.
LMSTUDIO_VERSION="$version" LMSTUDIO_HASH="$hash" perl -i -pe '
  s/^(\s*version = ")[^"]*(";)/$1$ENV{LMSTUDIO_VERSION}$2/;
  s/^(\s*sha256 = ")[^"]*(";)/$1$ENV{LMSTUDIO_HASH}$2/;
' "$overlay_file"

echo "Updated $overlay_file to LM Studio $version ($hash)"
