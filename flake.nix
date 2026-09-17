{
  description = "NixOS laptop and macOS Studio configurations";

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
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      darwinConfigurations.mac-studio = inputs.nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = {
          inherit inputs;
          hostname = "mac-studio";
          username = "jdreier";
        };
        modules = import ./hosts/mac-studio { inherit inputs; };
      };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = { inherit inputs; };

        modules = [ ./hosts/nixos ];
      };

      nixosConfigurations.ghrunner = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/ghrunner ];
      };

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
