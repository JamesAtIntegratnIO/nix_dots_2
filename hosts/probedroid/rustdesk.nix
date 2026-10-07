{ lib, pkgs, ... }:

let
  # RustDesk without Tailscale on her PCs: the Pi listens on its tailnet
  # address and forwards to each PC's RustDesk direct-IP port (21118). Connect
  # from the Mac to probedroid:<port>. On each PC: RustDesk installed as a
  # service, Direct IP access on, a permanent password, the IP whitelist set to
  # this Pi's LAN IP, and a DHCP reservation on her router.
  #
  # A null target means no forward. Fill it in on site, because a guessed
  # 192.168.1.x would reach a HomeNet device while the Pi is still at home.
  rustdeskForwards = {
    "21118" = null; # TODO: her PC's reserved LAN IP
  };
in
{
  systemd.services = lib.mapAttrs' (
    port: target:
    lib.nameValuePair "rustdesk-forward-${port}" {
      description = "Forward tailnet :${port} to RustDesk at ${target}:21118";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${port},fork,reuseaddr TCP:${target}:21118";
        DynamicUser = true;
        Restart = "always";
      };
    }
  ) (lib.filterAttrs (_: target: target != null) rustdeskForwards);
}
