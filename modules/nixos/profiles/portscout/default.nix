# portscout: plug the PocketTerm35 into an Ethernet port and see what the port
# is -- link speed, the switch and port on the other end (LLDP/CDP), tagged
# VLANs, the DHCP lease, and whether gateway, DNS and internet answer.
#
#   portscout-ui     touch dashboard for the 640x480 panel (./ui.py; Super+N,
#                    the tools menu, or a tap on the plug-in notification)
#   portscout        the same checks as text or --json, e.g. over SSH (./core.py)
#   portscout-watch  started by Sway; raises the "Ethernet connected"
#                    notification when the link comes up
#
# The dashboard starts passive (listen only, plus what any client does) and
# has a button to go active: ARP sweep, DHCP discover, iperf3.
#
# The port has two modes, each a NetworkManager profile:
#   scout  what every plug-in comes up as. The port gets an address, but all
#          its routes live in a routing table of their own and its DNS is
#          ignored, so the handheld's own traffic, DNS and Tailscale stay on
#          Wi-Fi as if the cable were not there. portscout's checks reach the
#          port because they bind to the interface.
#   live   an ordinary wired connection (default route, DNS). Chosen with the
#          dashboard's SCOUT/LIVE button or `portscout mode live`; it never
#          autoconnects, so the next link-up is scout again.
{ lib, pkgs, ... }:

let
  p = import ../cyberdeck/palette.nix;

  # The Pi 5's built-in RJ45.
  iface = "end0";
  # LAN address of an `iperf3 -s` for the dashboard's speed test; empty hides
  # it. Not a tailnet name: the test is bound to the wired interface.
  iperfServer = "";

  scoutProfile = "portscout-scout";
  liveProfile = "portscout-live";
  scoutTable = 100;
  # Both rules sit ahead of Tailscale's (5210-5270) and outside the 5200-5299
  # range tailscaled treats as its own.
  oifRulePref = 5000; # sockets bound to the port; NetworkManager installs it
  srcRulePref = 5001; # the port's own address; the hook below installs it
  oifRule = "priority ${toString oifRulePref} oif ${iface} table ${toString scoutTable}";

  # The one rule a profile cannot hold, because it names the DHCP address:
  # "from <the port's address> lookup scoutTable". The firewall's strict
  # reverse-path check looks a reply up as (to its sender, from our address,
  # no interface), so this is what lets replies to the scout checks back in
  # without loosening that check.
  scoutRuleHook = pkgs.writeShellScript "portscout-scout-rule" ''
    [ "$1" = ${iface} ] || exit 0
    case "$2" in pre-up | dhcp4-change | down) ;; *) exit 0 ;; esac
    ip=${pkgs.iproute2}/bin/ip

    want=
    if [ "$2" != down ] && [ "''${CONNECTION_ID:-}" = ${scoutProfile} ]; then
      # Never an address another interface also holds: the rule would pull
      # that interface's traffic onto the port.
      others=$($ip -4 -o addr show scope global | while read -r _ dev _ a _; do
        [ "$dev" = ${iface} ] || printf ' %s ' "''${a%%/*}"; done)
      want=$($ip -4 -o addr show dev ${iface} scope global | while read -r _ _ _ a _; do
        case "$others" in *" ''${a%%/*} "*) ;; *) printf '%s ' "''${a%%/*}" ;; esac; done)
    fi
    have=$($ip -4 rule show pref ${toString srcRulePref} |
      while read -r _ _ a _; do printf '%s ' "$a"; done)
    [ "$want" = "$have" ] && exit 0

    while $ip -4 rule del pref ${toString srcRulePref} 2>/dev/null; do :; done
    for a in $want; do
      $ip -4 rule add pref ${toString srcRulePref} from "$a" lookup ${toString scoutTable}
    done
  '';

  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);

  tools = with pkgs; [
    ethtool
    lldpd # lldpcli
    iproute2
    networkmanager # nmcli: the DHCP lease
    curl
    tcpdump
    arp-scan
    nmap
    iperf3
    coreutils
    sway # swaymsg, to focus a running dashboard
  ];

  # MAC prefix -> vendor, in arp-scan's format. arp-scan's bundled list dates
  # from its 2022 release and knows neither the Pi 5 nor recent Ubiquiti
  # prefixes; hwdata's is current. Passed as --macfile, so it adds to that
  # list; it does replace arp-scan's small mac-vendor.txt (QEMU, VRRP, HSRP
  # and the like), which is therefore appended.
  ouiFile = pkgs.runCommand "portscout-oui.txt" { } ''
    ${pkgs.gawk}/bin/awk -F'\t' '/\(base 16\)/ {
      split($1, a, " "); sub(/\r$/, "", $NF); print a[1] "\t" $NF
    }' ${pkgs.hwdata}/share/hwdata/oui.txt > $out
    test -s $out
    cat ${pkgs.arp-scan}/etc/arp-scan/mac-vendor.txt >> $out
  '';

  palette = pkgs.writeText "portscout-palette.json" (builtins.toJSON (removeAttrs p [ "ansi" ]));

  portscout = pkgs.stdenv.mkDerivation {
    pname = "portscout";
    version = "1";
    dontUnpack = true;
    nativeBuildInputs = with pkgs; [
      wrapGAppsHook4
      gobject-introspection
      makeWrapper
    ];
    buildInputs = [ pkgs.gtk4 ];
    installPhase = ''
      install -Dm644 ${./core.py} $out/lib/portscout/core.py
      install -Dm644 ${./ui.py} $out/lib/portscout/ui.py
    '';
    # Wrapped by hand so both entry points share the environment and the GTK
    # wrapper arguments only go on the one that needs them. The tools go in
    # front of the session's PATH, which is still where sudo and ping come from.
    dontWrapGApps = true;
    postFixup = ''
      common=(
        --prefix PATH : ${lib.makeBinPath tools}
        --set PORTSCOUT_IFACE ${iface}
        --set PORTSCOUT_IPERF_SERVER "${iperfServer}"
        --set PORTSCOUT_OUI ${ouiFile}
        --set PORTSCOUT_SCOUT ${scoutProfile}
        --set PORTSCOUT_LIVE ${liveProfile}
      )
      makeWrapper ${python}/bin/python3 $out/bin/portscout \
        "''${common[@]}" --add-flags $out/lib/portscout/core.py
      makeWrapper ${python}/bin/python3 $out/bin/portscout-ui \
        "''${common[@]}" "''${gappsWrapperArgs[@]}" \
        --set PORTSCOUT_PALETTE ${palette} \
        --add-flags $out/lib/portscout/ui.py
    '';
  };

  watch = pkgs.writeShellApplication {
    name = "portscout-watch";
    runtimeInputs = with pkgs; [
      iproute2
      libnotify
      sway
      jq
      coreutils
      portscout
    ];
    text = ''
      if=${iface}
      # Reading carrier fails outright while the interface is down.
      carrier() { cat "/sys/class/net/$if/carrier" 2>/dev/null || echo 0; }

      prev=$(carrier)
      ip -o monitor link dev "$if" | while read -r _; do
        cur=$(carrier)
        if [ "$cur" = 1 ] && [ "$prev" != 1 ]; then
          # Stamp the error counters at link-up, so a later look at this link
          # doesn't count the previous port's errors (error_baseline, core.py).
          portscout link >/dev/null 2>&1 || true
          # A dashboard that is on screen reruns its checks in plain view. One
          # left on another workspace does too, but unseen, so that still gets
          # the notification; a tap then brings the same window forward.
          tree=$(swaymsg -t get_tree)
          if ! jq -e '[.. | objects | select(.app_id? == "io.integratn.portscout") | .visible] | any' \
            <<<"$tree" >/dev/null; then
            (
              # Blocks until the notification is tapped or times out; mako
              # reports a tap as the default action (on-touch in ../cyberdeck).
              action=$(notify-send -a portscout -t 20000 -A default=Diagnose \
                "Ethernet connected" "$if link is up · tap to diagnose") || true
              if [ "$action" = default ]; then exec portscout-ui; fi
            ) &
          fi
        fi
        prev=$cur
      done
    '';
  };
in
{
  environment.systemPackages = [
    portscout
    watch
  ];

  # Hears the switch's LLDP/CDP announcements for the dashboard. Receive-only
  # (-r): the handheld never announces itself to a network it is plugged into.
  # -c adds CDP, -I keeps it off Wi-Fi and Tailscale.
  services.lldpd = {
    enable = true;
    extraArgs = [
      "-r"
      "-c"
      "-I"
      iface
    ];
  };

  networking.networkmanager = {
    ensureProfiles.profiles = {
      ${scoutProfile} = {
        connection = {
          id = scoutProfile;
          uuid = "d3d062f0-eeac-4330-ae66-5b73a2fbd8f1";
          type = "ethernet";
          interface-name = iface;
          autoconnect = true;
          autoconnect-priority = 999; # beats any wired profile saved earlier
          autoconnect-retries = 0; # keep trying for as long as the cable is in
        };
        ipv4 = {
          method = "auto";
          route-table = scoutTable;
          ignore-auto-dns = true;
          routing-rule1 = oifRule;
          # Wait this long for DHCPv4 before IPv6 alone may finish the
          # activation, so the hook above normally runs with the address set.
          required-timeout = 15000;
          # A switch port can take 30 s of spanning tree before it forwards.
          # The DHCP client backs off (4, 8, 16, 32 s), so with the default
          # 45 s timeout its next try after that is the retry at 45 s; giving
          # up at 15 s and starting over lands one at 30 s instead.
          dhcp-timeout = 15;
        };
        ipv6 = {
          method = "auto";
          addr-gen-mode = "stable-privacy";
          route-table = scoutTable;
          ignore-auto-dns = true;
          routing-rule1 = oifRule;
        };
      };
      ${liveProfile} = {
        connection = {
          id = liveProfile;
          uuid = "ab481025-f7b9-4bbc-a754-d6ada1737000";
          type = "ethernet";
          interface-name = iface;
          autoconnect = false;
        };
        ipv4.method = "auto";
        ipv6 = {
          method = "auto";
          addr-gen-mode = "stable-privacy";
        };
      };
    };

    settings = {
      # No auto-created "Wired connection 1" for this port (USB tethers keep
      # theirs), so scout is the only profile that can autoconnect on it.
      main.no-auto-default = "interface-name:${iface}";
      # Act on carrier loss after 1 s instead of 6, so that moving the cable
      # to another port ends a live connection and the new port starts in scout.
      device-portscout = {
        match-device = "interface-name:${iface}";
        carrier-wait-timeout = 1000;
      };
    };

    dispatcherScripts = [
      {
        source = scoutRuleHook;
        type = "pre-up"; # NetworkManager waits for it before "connected"
      }
      { source = scoutRuleHook; } # dhcp4-change, down
    ];
  };

  # With Wi-Fi and the wired port on one subnet, each interface must answer
  # ARP only for its own address; the kernel default is to answer for any
  # local address on any interface, which sends Wi-Fi's traffic to the port.
  boot.kernel.sysctl."net.ipv4.conf.all.arp_ignore" = 1;

  environment.etc."sway/config.d/portscout.conf".text = ''
    exec portscout-watch
    bindsym $mod+n exec portscout-ui
  '';
}
