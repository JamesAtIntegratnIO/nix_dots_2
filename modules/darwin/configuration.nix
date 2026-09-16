{
  pkgs,
  hostname,
  username,
  ...
}:
let
  packages = import ./packages.nix { inherit pkgs; };
  rustdesk = pkgs.callPackage ./rustdesk-package.nix { };
in
{
  imports = [
    ./local-ai.nix
    ./docker.nix
    ./github-runner.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Match this host's architecture (Apple Silicon Mac Studio).
  nixpkgs.hostPlatform = "aarch64-darwin";

  networking.hostName = hostname;

  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  # IMPORTANT: LM Studio MUST be a real copied app bundle in /Applications.
  # DO NOT switch this back to a symlink: LaunchServices/Spotlight may fail to
  # discover symlinked app bundles in /Applications on macOS.
  # We copy from the Nix store each activation so app discovery remains reliable.
  system.activationScripts.applications.text = pkgs.lib.mkForce ''
    echo "setting up /Applications/LM Studio.app..." >&2
    app_source="$(/usr/bin/find ${pkgs.lmstudio}/Applications -maxdepth 1 -type d -name '*.app' | /usr/bin/head -n 1)"
    if [ -n "$app_source" ]; then
      rm -rf "/Applications/LM Studio.app"
      /usr/bin/ditto "$app_source" "/Applications/LM Studio.app"
      /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/LM Studio.app" >/dev/null 2>&1 || true
    else
      echo "warning: could not find LM Studio app bundle under ${pkgs.lmstudio}/Applications" >&2
    fi
  '';

  environment.systemPackages = packages.all;

  system.activationScripts.postActivation.text = ''
    /usr/bin/ditto "${rustdesk}/Applications/RustDesk.app" "/Applications/RustDesk.app"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/RustDesk.app"
  '';

  nix.enable = false;

  system.primaryUser = username;

  # Used for backwards-compatible defaults; bump only after reading release notes.
  system.stateVersion = 5;
}
