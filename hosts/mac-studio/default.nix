{ inputs }:

# Keep the original top-level module order so generated profiles stay identical.
[
  ../../modules/darwin/configuration.nix
  inputs.mac-app-util.darwinModules.default
  ../../modules/darwin/tailscale.nix
  { nixpkgs.config.allowUnfree = true; }
  { nixpkgs.overlays = [ (import ../../modules/darwin/overlays.nix) ]; }
  inputs.darwin-home-manager.darwinModules.home-manager
  {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs;
        username = "jdreier";
      };
      users.jdreier = import ../../home/jdreier;
    };
  }
]
