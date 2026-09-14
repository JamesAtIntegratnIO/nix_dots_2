{ ... }:

{
  services.tailscale = {
    enable = true;
    # Allow direct encrypted peer connections; this does not expose SSH.
    openFirewall = true;
  };
}
