# WiFi Pineapple Pager

A Hak5 wireless-auditing box that pairs with this deck. **Authorized use only:**
assess only networks and devices you own or have written permission to test.

## One command

    pager           bring the link up, open the dashboard in Firefox, and SSH in
    pager web       open the Virtual Pager dashboard
    pager ssh       drop into a root shell
    pager status    show link / route / reachability

The Pager lives at **172.16.52.1**; the Virtual Pager web UI is at
**http://172.16.52.1:1471** (root password = the one you set on the device).

## Two ways it connects

- **Wi-Fi management AP**: the Pager's `PagerAndChill` network (WPA2), joined
  via the USB Wi-Fi dongle (`wlu1`) so the built-in Wi-Fi keeps your internet.
  It's management-only (see *Networking*). This is the usual path.
- **USB-C tether**: plug into a **USB-A** port on the Pi with a data cable. The
  Pager appears as an RTL8153 USB-ethernet gadget and hands out DHCP on the same
  172.16.52.0/24. This needs the raised USB current budget (already set), or the
  port over-currents and the Pager never enumerates.

Either way, NetworkManager brings it up and `pager` handles the rest.

## Driving it (no host CLI exists)

Hak5 ships no host-side CLI. Your options:

- **Virtual Pager dashboard** (`:1471`): the full tactile UI in the browser,
  plus a **web terminal** (a root shell with no SSH client) and downloads for
  captured handshakes / loot.
- **SSH**: `ssh root@172.16.52.1`. Underneath it's OpenWrt-flavored Linux
  (busybox plus Pager helpers like `WIFI_MGMT_AP`).
- **Payloads**: DuckyScript + Bash scripts that run *on the device*, from the
  official `hak5/wifipineapplepager-payloads` repo. Author them, drop them on
  the Pager, fire them from its UI. This is the automation surface.
- A REST API almost certainly backs the `:1471` UI (the Mark VII had one), but
  Hak5's Pager API docs are "coming soon", so it's undocumented for now.

## On-device controls

D-pad to move, **A** (green) to confirm, **B** (red) to go back or cancel.
First-boot setup sets a PIN (locks the on-device UI) and the **root password**
(used for SSH and the Virtual Pager).

## If it won't connect

- `pager status`: is `172.16.52.1` reachable?
- Is the Pager powered and booted to its dashboard (not stuck rebooting)?
- On the AP path: is `PagerAndChill` in range? `nmcli device wifi list | grep -i pager`
- On the USB path: `lsusb` should show an RTL8153, and `dmesg | tail` shows
  over-current or enumeration errors. Use a **data** cable in a **USB-A** port.
