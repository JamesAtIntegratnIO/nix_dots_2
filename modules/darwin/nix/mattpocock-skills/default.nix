# mattpocock/skills — fetch and package Matt Pocock's AI coding agent skills.
#
# Pinned to a release tag so the derivation is fully reproducible.
# Upstream: https://github.com/mattpocock/skills
#
# Usage:
#   pkgs.callPackage ./modules/nix/mattpocock-skills.nix {}
#
# Returns a derivation whose $out/skills/ contains the full skills tree:
#   skills/engineering/tdd/SKILL.md
#   skills/productivity/grill-me/SKILL.md
#   skills/misc/setup-pre-commit/SKILL.md
#   ...
{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  name = "mattpocock-skills";

  src = pkgs.fetchFromGitHub {
    owner = "mattpocock";
    repo  = "skills";
    rev   = "v1.0.1";
    # v1.0.1 tarball — computed via `nix-prefetch-url --unpack <url>`
    outputHashAlgo = "sha256";
    outputHash     = "17rdd42w6rspr5ss2h4pq6fww4dkcx765y3xng5flldr47wx1qcy";
  };

  installPhase = ''
    mkdir -p "$out/skills"
    cp -rL skills/. "$out/skills/"
  '';
}
