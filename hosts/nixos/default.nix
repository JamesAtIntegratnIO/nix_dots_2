{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-9th-gen
    inputs.home-manager.nixosModules.home-manager
    ./hardware-configuration.nix
    ../../modules/nixos/core
    ../../modules/nixos/profiles/cinnamon.nix
    ../../modules/nixos/profiles/development.nix
    ../../modules/nixos/profiles/element.nix
    ../../modules/nixos/profiles/laptop.nix
    ../../modules/nixos/profiles/tailscale.nix
  ];

  networking.hostName = "nixos";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  users.users.boboysdadda = {
    isNormalUser = true;
    description = "boboysdadda";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

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
