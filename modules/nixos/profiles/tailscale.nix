{ ... }:

{
  services.tailscale = {
    enable = true;
    # Allow direct encrypted peer connections; this does not expose SSH
    # (a host that wants it opens port 22 on tailscale0 itself).
    openFirewall = true;
  };
}
