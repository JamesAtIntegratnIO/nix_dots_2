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

  # mac-app-util (imported by this host) creates trampoline .app wrappers that
  # Spotlight and Launchpad index, so GUI apps no longer need to be copied into
  # /Applications by hand. RustDesk is listed here rather than copied during
  # activation so it gets a trampoline like everything else.
  environment.systemPackages = packages.all ++ [ rustdesk ];

  nix.enable = false;

  system.primaryUser = username;

  # Used for backwards-compatible defaults; bump only after reading release notes.
  system.stateVersion = 5;
}
