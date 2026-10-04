# Networking

Dual-homed by default: real Wi-Fi for internet + the Pager's network at once.

| Iface | What | Normal state |
|-------|------|--------------|
| `wld0` | Built-in Wi-Fi | Infra Wi-Fi (e.g. `InfraAndChill`); internet |
| `wlu1` | USB Wi-Fi dongle | Pager `PagerAndChill` (management only) |
| `tailscale0` | Tailscale | Mesh VPN |
| `end0` | Ethernet (RJ45) | Down unless a cable is in |

A USB-C tether to the Pager shows up as a `usb0`/`enx…` RTL8153 gadget on the
same 172.16.52.0/24.

## What is this Ethernet port? (portscout)

Plug a cable into `end0` and tap the "Ethernet connected" notification, or
press `Super+n` (also first in the `Super+t` tools menu).

| Tile | Shows |
|------|-------|
| LINK | Negotiated speed/duplex, what the switch offers, errors on this link |
| SWITCH | Switch name, port and management IP from LLDP/CDP (up to 60 s) |
| ADDRESS | DHCP lease: address, gateway, DNS, server, lease time |
| PATH | Gateway ping, DNS lookup, internet check, public IP, path MTU |
| VLANS | 802.1Q tags heard in 8 s (none = access port) |
| NEIGHBORS | ARP sweep of the segment (ACTIVE mode only) |

Tap a tile for everything behind it; the arrow goes back. The bar's buttons:
PASSIVE/ACTIVE, rescan, save a JSON report to `~/portscout/`.

PASSIVE only listens and does what any client does. ACTIVE sweeps for
neighbors and adds a probe button on some detail pages: DHCP server discovery
(ADDRESS), iperf3 (PATH, once `iperfServer` is set in
`portscout/default.nix`), sweep again (NEIGHBORS). On a subnet bigger than a
/22 the sweep only covers the /24 around the handheld. There is no cable
test: the Pi 5's PHY driver doesn't support one.

The plug-in notification is skipped only while the dashboard is on screen.

Every test is bound to `end0`, so Wi-Fi and Tailscale don't skew the answer.

### Scout vs live

The port comes up in **scout** on every plug-in: it has an address for the
checks, but its routes sit in table 100 and its DNS is ignored, so the
handheld's own traffic, DNS and Tailscale stay on Wi-Fi. With Wi-Fi off the
handheld is offline in scout even on a working port.

The bar's SCOUT/LIVE button (or the CLI) makes it an ordinary connection:
**live** takes the default route and DNS, and lasts until the link drops.

    portscout mode              # scout | live | down | other
    portscout mode live         # use the port as the uplink
    portscout mode scout        # back to probe-only
    ip rule; ip route show table 100    # scout's rules (5000, 5001) and routes

    portscout                   # the passive checks as text
    portscout --active --json   # everything, machine-readable
    portscout link switch       # just these checks

## Inspect

    ip -br addr                 # addresses per interface
    ip route                    # exactly one `default`, via wld0
    ip route get 1.1.1.1        # confirm internet path = wld0
    nmcli device                # per-device state
    nmcli -g IP4.DNS device show wld0

## Wi-Fi

    nmcli device wifi list
    nmcli --ask device wifi connect "SSID"
    nmcli connection show --active
    nmcli connection delete "SSID"      # forget

## Tailscale

    tailscale status
    tailscale ip -4
    sudo tailscale up                   # (re)authenticate

## Pager stays management-only

The `PagerAndChill` profile is set `never-default` + `ignore-auto-dns`, so the
Pager can't become your route or DNS. Verify:

    ip route | grep -c '^default'       # want: 1  (via wld0)
    nmcli -g ipv4.never-default connection show PagerAndChill   # want: yes

If a second `default` (via 172.16.52.1) appears, re-apply:

    sudo nmcli connection modify PagerAndChill \
      ipv4.never-default yes ipv4.ignore-auto-dns yes \
      ipv6.never-default yes ipv6.ignore-auto-dns yes
    sudo nmcli connection up PagerAndChill
