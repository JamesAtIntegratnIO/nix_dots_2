{ lib, buildGoModule, fetchFromGitHub }:

# NOTE: This builds the cq binary from Go source, which adds rebuild time.
# If a pre-built binary is available from a GitHub release (e.g.,
# https://github.com/mozilla-ai/cq/releases), consider replacing this
# derivation with a fetchFromGitHub that points to the pre-built artifact
# to speed up rebuilds significantly.

buildGoModule rec {
  pname = "cq";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "mozilla-ai";
    repo = "cq";
    rev = "cli/v${version}";
    hash = "sha256-2bv1FgrbJlb+lBFgJm8izDu6hQf8UwiJxdzua9Xoi8k=";
  };

  # The CLI lives in the cli/ subdirectory of the monorepo.
  # The replace directive in go.mod is commented out, so all deps
  # are fetched from the module proxy normally.
  modRoot = "cli";

  vendorHash = "sha256-TCHb0/npCwXzCbWcQMD9t0U5ZP+u0H11+ThLX+YWaRI=";

  # The Go module builds a binary named "cli" (the subdirectory name).
  # Rename it to "cq" so it is on PATH as expected.
  postInstall = ''
    mv $out/bin/cli $out/bin/cq
  '';

  meta = with lib; {
    description = "Shared agent learning memory CLI (MCP stdio server)";
    homepage = "https://github.com/mozilla-ai/cq";
    license = licenses.asl20;
    mainProgram = "cq";
    platforms = platforms.unix;
  };
}
