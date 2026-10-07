{
  inputs,
  pkgs,
  ...
}:

let
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIESq1wdY7diOloASvawJgjjThP6kzDWC/J3NIzZu5QVe james@integratn.io";
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-9th-gen
    inputs.home-manager.nixosModules.home-manager
    ./hardware-configuration.nix
    ../../modules/nixos/core
    ../../modules/nixos/profiles/cinnamon.nix
    ../../modules/nixos/profiles/cyberdeck/cinnamon.nix
    ../../modules/nixos/profiles/development.nix
    ../../modules/nixos/profiles/element.nix
    ../../modules/nixos/profiles/laptop.nix
    ../../modules/nixos/profiles/tailscale.nix
  ];

  networking.hostName = "carbonite";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  users.users.boboysdadda = {
    isNormalUser = true;
    description = "boboysdadda";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # SSH for remote rebuilds from the Mac, key-only. The laptop roams onto
  # networks it does not control, so the port is opened on the tailnet
  # interface alone and stays closed on Wi-Fi and Ethernet. root takes the
  # key because a rebuild needs it and sudo here asks for a password.
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
  users.users.root.openssh.authorizedKeys.keys = [ sshKey ];
  users.users.boboysdadda.openssh.authorizedKeys.keys = [ sshKey ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    backupFileExtension = "hm-backup";
    users.boboysdadda = import ../../home/boboysdadda;
  };

  # Keep this at the release used for the initial installation. It controls
  # compatibility defaults and should not be changed during normal upgrades.
  system.stateVersion = "26.05";
}
