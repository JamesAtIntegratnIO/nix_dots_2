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
      src = prev.fetchurl {
        url = "https://installers.lmstudio.ai/darwin/arm64/${version}/LM-Studio-${version}-arm64.dmg";
        sha256 = "sha256-i6uFfD0pAOFKtGQ18NFHHeBo8WXnYbucF3CT6KJeF3Q=";
      };
    }
  );
}
