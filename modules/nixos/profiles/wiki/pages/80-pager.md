# WiFi Pineapple Pager

Hak5 wireless-auditing box. **Authorized use only:** assess only networks and
devices you own or have written permission to test.

## `pager` command

    pager           connect, open the dashboard in Firefox, and SSH in
    pager web       open the Virtual Pager dashboard only
    pager ssh       open a root shell only
    pager status    link / route / reachability

Address `172.16.52.1`, web UI `http://172.16.52.1:1471`, SSH `root@172.16.52.1`
(root password = the one set on the device).

## Manual connect / inspect

    nmcli connection up PagerAndChill           # bring the mgmt AP up
    ping -c2 172.16.52.1                         # reachable?
    ssh root@172.16.52.1                         # root shell (OpenWrt-ish)
    ssh root@172.16.52.1 'WIFI_MGMT_AP'          # example on-device helper
    curl -s http://172.16.52.1:1471/ | head      # confirm the UI is up

## Two connection paths

- **Wi-Fi mgmt AP**: `PagerAndChill` (WPA2) over the USB dongle (`wlu1`), so
  the built-in Wi-Fi keeps internet. Management-only (see *networking*). Usual path.
- **USB-C tether**: data cable into a **USB-A** port on the Pi; the Pager
  appears as an RTL8153 gadget with DHCP on the same /24. Needs the raised USB
  current budget (already set) or the port over-currents.

## Driving it (no host CLI ships)

- **Dashboard** (`:1471`): full UI, a **web terminal** (root shell, no SSH
  client), and downloads for handshakes / loot.
- **SSH**: busybox + Pager helpers.
- **Payloads**: DuckyScript + Bash on-device, from `hak5/wifipineapplepager-payloads`.
- A REST API likely backs `:1471` (the Mark VII had one) but Pager API docs are
  "coming soon".

## Full official docs (offline)

    pager-docs sync         # mirror Hak5's docs to a local cache (needs network)
    pager-docs              # browse them offline (glow + fzf)
    pager-docs pineap       # jump to a page by name, e.g. PineAP / firewall / recon
    pager-docs ls           # list cached pages

Hak5 publishes no git source for the Pager docs, so `pager-docs` pulls the
GitBook Markdown exports into `~/.cache/pager-docs`. Re-run `sync` when online
to refresh.

## On-device controls

D-pad moves, **A** (green) confirms, **B** (red) backs out. First boot sets a
PIN (locks the UI) and the root password (SSH + Virtual Pager).

## Troubleshoot

    pager status                                 # reachable?
    nmcli device wifi list | grep -i pager       # AP in range?
    lsusb | grep -i realtek                       # USB path: RTL8153 present?
    dmesg | tail -20                              # over-current / enumeration

Use a **data** cable in a **USB-A** port. Confirm the Pager is booted to its
dashboard, not stuck rebooting.
