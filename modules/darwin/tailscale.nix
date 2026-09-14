{ ... }:

{
  # Use the Nix-managed system daemon for unattended access.
  services.tailscale.enable = true;
  launchd.daemons.tailscaled.serviceConfig.KeepAlive = true;
}
