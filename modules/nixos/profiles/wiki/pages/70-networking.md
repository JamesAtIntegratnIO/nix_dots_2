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
