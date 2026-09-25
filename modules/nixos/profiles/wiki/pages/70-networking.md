# Networking

NetworkManager runs the show. The deck is normally **dual-homed**: on the real
Wi-Fi for internet *and* on the Pager's network at the same time.

## Interfaces

| Iface | What | Typical state |
|-------|------|---------------|
| `wld0` | Built-in Wi-Fi | Joined to your infra Wi-Fi (e.g. `InfraAndChill`) — the internet uplink |
| `wlu1` | USB Wi-Fi dongle | Joined to the Pager's `PagerAndChill` AP (management only) |
| `tailscale0` | Tailscale | Remote access / mesh VPN |
| `end0` | Built-in Ethernet (RJ45) | Down unless a cable is plugged |

(A USB-C tether to the Pager shows up instead as a `usb0`/`enx…` RTL8153
ethernet gadget — same 172.16.52.0/24.)

## Joining Wi-Fi

- By hand: `Super+w` (netmenu) → pick a network.
- CLI: `nmcli device wifi list`, `nmcli device wifi connect "<SSID>"`.

## Why the Pager can't hijack your traffic

The `PagerAndChill` profile is set **management-only**:

- `never-default` — it never becomes the default route, so internet always
  stays on `wld0`.
- `ignore-auto-dns` — its DNS server (172.16.52.1) is dropped, so name lookups
  don't flow through the auditing box.

Result: you can always reach `172.16.52.0/24` (the Pager), but your browsing
and DNS never route through it. Check with `ip route` — there should be exactly
one `default` line, via `wld0`.

## Handy checks

    ip -br addr                 # addresses per interface
    ip route                    # one default via wld0 = correct
    nmcli device                # connection state per device
    tailscale status            # mesh peers
