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
    ./linux-builder.nix
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

  # nix-darwin rsyncs these into /Applications/Nix Apps as real bundles, which
  # Spotlight and LaunchServices both index -- no hand-copying needed. RustDesk
  # is listed here rather than copied during activation for the same reason.
  environment.systemPackages = packages.all ++ [ rustdesk ];

  nix.enable = false;

  system.primaryUser = username;

  # The Studio is reached remotely, and FileVault holds an unattended reboot
  # at the pre-boot unlock screen, before Tailscale, SSH or RustDesk start. A
  # macOS update must not reboot it on its own; security responses and XProtect
  # data still install. Plan reboots with `sudo fdesetup authrestart`.
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
  power.restartAfterPowerFailure = true;

  # Used for backwards-compatible defaults; bump only after reading release notes.
  system.stateVersion = 5;
}
