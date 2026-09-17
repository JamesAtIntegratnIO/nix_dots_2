# x86_64 GitHub Actions runner: VM 120 on the Proxmox host at 192.168.0.10.
{
  inputs,
  modulesPath,
  ...
}:

let
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIESq1wdY7diOloASvawJgjjThP6kzDWC/J3NIzZu5QVe james@integratn.io";
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    inputs.disko.nixosModules.disko
    ./disko.nix
    ../../modules/nixos/core/locale.nix
    ../../modules/nixos/core/nix.nix
    ../../modules/nixos/github-runner.nix
  ];

  networking.hostName = "ghrunner";
  networking.useDHCP = true;

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  services.qemuGuest.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [ sshKey ];
  users.users.jdreier = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = [ sshKey ];
  };
  security.sudo.wheelNeedsPassword = false;

  # Lets `nixos-rebuild --target-host` push closures built elsewhere.
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  # Keep this at the release used for the initial installation.
  system.stateVersion = "26.05";
}
