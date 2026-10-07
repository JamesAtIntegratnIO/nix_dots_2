# Mom's LAN is 192.168.1.0/24. The Pi takes wired DHCP from her router and
# should get a reservation there, because her router's static route (for Plex,
# below) points at it.
#
# Tailscale roles:
#   - subnet router for her LAN: reach her router UI, printers and PCs
#     from the tailnet without installing anything on them (RustDesk goes
#     through the port forward in rustdesk.nix instead)
#   - exit node: test from her public IP
#   - accept routes: pull in the home routes so her LAN can reach home
#     services through this box. Plex is on Tower (10.0.0.12, Homelab VLAN):
#     Tower advertises 10.0.0.12/32, and her router has a static route
#     10.0.0.12/32 -> this box's reserved LAN IP.
{ pkgs, ... }:

let
  # OVERLAP: home's HomeNet is also 192.168.1.0/24. Once this route is
  # approved, every tailnet device that accepts routes sends all 192.168.1.x
  # traffic to Mom's, and HomeNet clients still can't reach her LAN. Don't
  # approve it until this is resolved on site: renumber her LAN (and change it
  # here) or switch to Tailscale 4via6.
  lan = "192.168.1.0/24";
in
{
  services.tailscale = {
    # Forwarding + loose rp_filter, for both advertising and accepting routes.
    useRoutingFeatures = "both";
    extraSetFlags = [
      "--advertise-routes=${lan}"
      "--advertise-exit-node"
      "--accept-routes"
    ];
  };

  # Her devices reach home services by sending to this box (via a static route
  # on her router). Masquerade them onto tailscale0 so replies come back here
  # and tailnet ACLs see this node as the source, rather than a 192.168.1.x
  # address that also exists at home.
  networking.nat = {
    enable = true;
    externalInterface = "tailscale0";
    internalIPs = [ lan ];
  };

  # With --accept-routes, Tailscale's routing table (rule priority 5270) wins
  # over the main table. Home's HomeNet is also 192.168.1.0/24, so if that route
  # is ever advertised, this box would send its own LAN into the tailnet and
  # drop off Mom's network. Pin the local subnet to the main table first.
  systemd.services.lan-route-guard = {
    description = "Keep ${lan} on the local LAN despite accepted Tailscale routes";
    wantedBy = [ "multi-user.target" ];
    before = [ "tailscaled.service" ];
    after = [ "network-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.iproute2 ];
    script = ''
      ip rule del to ${lan} lookup main priority 5200 2>/dev/null || true
      ip rule add to ${lan} lookup main priority 5200
    '';
    preStop = "ip rule del to ${lan} lookup main priority 5200 || true";
  };

  # Tailscale's recommended NIC setting for subnet routers/exit nodes:
  # https://tailscale.com/s/ethtool-config-udp-gro
  systemd.services.udp-gro-forwarding = {
    description = "Enable UDP GRO forwarding on end0 for Tailscale";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.ethtool ];
    script = "ethtool -K end0 rx-udp-gro-forwarding on rx-gro-list off";
  };

  # SSH stays open on the LAN (key-only) for the first `tailscale up` at home;
  # everything else, including node_exporter, is tailnet-only.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
