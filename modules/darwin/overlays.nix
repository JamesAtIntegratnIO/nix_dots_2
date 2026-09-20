_: prev:

{
  # Preserve the Mac's workaround for the a2a-sdk test failure on Darwin.
  a2a-sdk = prev.a2a-sdk.overrideAttrs (old: {
    postPatch = ''
      rm -f tests/e2e/push_notifications/test_default_push_notification_support.py
    ''
    + (old.postPatch or "");
  });

  lmstudio = prev.lmstudio.overrideAttrs (
    _:
    let
      version = "0.4.25-1";
    in
    {
      inherit version;

      # The DMG now nests the bundle inside a "LM Studio <version>-arm64"
      # folder. Upstream pins sourceRoot to "." and installs with
      # `cp -r *.app`, which then matches nothing. Its custom unpackPhase
      # skips the postUnpack hook, so lift the bundle up in preInstall,
      # which installPhase does run.
      preInstall = ''
        app=$(find . -maxdepth 3 -type d -name '*.app' -print -quit)
        if [ -z "$app" ]; then
          echo "no .app bundle found in the LM Studio DMG" >&2
          exit 1
        fi
        if [ "$(dirname "$app")" != "." ]; then
          mv "$app" .
        fi
      '';

      src = prev.fetchurl {
        url = "https://installers.lmstudio.ai/darwin/arm64/${version}/LM-Studio-${version}-arm64.dmg";
        sha256 = "sha256-i6uFfD0pAOFKtGQ18NFHHeBo8WXnYbucF3CT6KJeF3Q=";
      };
    }
  );
}
