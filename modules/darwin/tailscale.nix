{ pkgs, inputs, ... }:

{
  # Use the Nix-managed system daemon for unattended access.
  services.tailscale.enable = true;
  # Same client as the NixOS hosts (see modules/nixos/profiles/tailscale.nix),
  # so Tailscale fixes don't wait on a darwin-nixpkgs bump.
  services.tailscale.package = inputs.tailscale-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.tailscale;
  launchd.daemons.tailscaled.serviceConfig.KeepAlive = true;
}
