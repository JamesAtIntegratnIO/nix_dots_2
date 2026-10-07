{
  description = "NixOS laptop and macOS Studio configurations";

  # PocketTerm35 (Raspberry Pi 5) pulls prebuilt vendor kernel/firmware from the
  # nixos-raspberrypi cache; the module also sets these at the system level.
  nixConfig = {
    extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Keep the Mac's existing versions independent of the NixOS laptop.
    darwin-nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin-home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "darwin-nixpkgs";
    };
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "darwin-nixpkgs";
    };
    openspec.url = "github:Fission-AI/OpenSpec";
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.6.19";

    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      flake = false;
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Raspberry Pi 5 support (vendor kernel, firmware, config.txt) for the
    # PocketTerm35. Keeps its own nixpkgs (26.05) to match the cached artifacts.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      darwinConfigurations.holocron = inputs.nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = {
          inherit inputs;
          hostname = "holocron";
          username = "jdreier";
        };
        modules = import ./hosts/holocron { inherit inputs; };
      };

      nixosConfigurations.carbonite = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = { inherit inputs; };

        modules = [ ./hosts/carbonite ];
      };

      nixosConfigurations.pitdroid = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/pitdroid ];
      };

      # PocketTerm35 handheld (Raspberry Pi 5). Uses the raspberrypi flake's
      # system builder so the vendor kernel/firmware overlays are in scope; it
      # pins aarch64-linux and its own nixpkgs internally.
      nixosConfigurations.datapad = inputs.nixos-raspberrypi.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/datapad ];
      };

      # Flashable first-install image: `nix build .#datapad-sdimage` on the
      # Mac Studio, then dd the result to the microSD card.
      nixosConfigurations.datapad-sdimage = inputs.nixos-raspberrypi.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/datapad
          inputs.nixos-raspberrypi.nixosModules.sd-image
        ];
      };

      # `nix build .#datapad-sdimage` (built on the aarch64 Mac Studio).
      packages.aarch64-linux.datapad-sdimage =
        inputs.self.nixosConfigurations.datapad-sdimage.config.system.build.sdImage;

      # Headless Pi 5 at Mom's house for remote network support.
      nixosConfigurations.probedroid = inputs.nixos-raspberrypi.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/probedroid ];
      };

      # First-install image, written to the NVMe drive (not an SD card):
      # `nix build .#packages.aarch64-linux.probedroid-image` on the Mac Studio.
      nixosConfigurations.probedroid-image = inputs.nixos-raspberrypi.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/probedroid
          inputs.nixos-raspberrypi.nixosModules.sd-image
        ];
      };

      packages.aarch64-linux.probedroid-image =
        inputs.self.nixosConfigurations.probedroid-image.config.system.build.sdImage;

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      devShells.${system}.default =
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.mkShellNoCC {
          packages = with pkgs; [
            deadnix
            git
            nil
            nixfmt-tree
            statix
          ];
        };
    };
}
