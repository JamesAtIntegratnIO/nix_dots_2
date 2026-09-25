# Quick menus

Touch-friendly rofi menus, all in the cyberdeck theme. A single tap picks a
row. Pressing the same hotkey again **closes** the menu instead of stacking a
second one. Each is also on the Waybar widgets.

| Keys | Menu | What it does |
|------|------|--------------|
| `Super+w` | **netmenu** | Wi-Fi: join a network (masked password prompt for new secured ones), disconnect, rescan, toggle the radio, or drop to `nmtui` |
| `Super+b` | **btmenu** | Bluetooth (rofi-bluetooth style): power / scan / pairable / discoverable, plus per-device connect / pair / trust / remove |
| `Super+v` | **volmenu** | Volume: mute, level presets, pick the output device, mic mute |
| `Super+Shift+e` | **powermenu** | Lock / log out / reboot / power off, with a confirm step |
| `Super+t` | **toolmenu** | Field tools from the pentest toolkit (opens them in a terminal) |

Notes:

- **netmenu** is the fastest way to join a new Wi-Fi network by hand; for the
  Pager's `PagerAndChill` network the `pager` command already handles it.
- **powermenu** is the same menu the power button and the bottom-edge swipe
  open.
- Everything here is a normal command too (e.g. `netmenu`, `btmenu`) if you'd
  rather bind or script it.
