# PocketTerm35

Offline reference for this deck: a Raspberry Pi 5 handheld running NixOS + Sway
on a 640x480 touch panel, with a built-in QWERTY keyboard and game controls.

## This wiki

    wiki            browse every topic (arrow / type to filter, Enter reads)
    wiki <query>    jump to matching topics, e.g. `wiki bright`
    wiki ls         list all topics
    wiki -h         help

Inside a topic: arrows / touch scroll, `q` quits.

## Cheat sheet

| Command | Does |
|---------|------|
| `pager` | Connect + open the WiFi Pineapple Pager dashboard + SSH |
| `nmcli device wifi list` | Scan Wi-Fi |
| `nmcli --ask device wifi connect "SSID"` | Join a network (prompts password) |
| `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+` | Volume up |
| `grim -g "$(slurp)" - \| wl-copy` | Region screenshot to clipboard |
| `swaylock -f -C /etc/swaylock/config` | Lock now |
| `ip -br addr` / `ip route` | Interfaces / routes |
| `systemctl --failed` | What's broken |

## Key bindings (Super = the logo key)

| Keys | Action |
|------|--------|
| `Super+Return` | Terminal |
| `Super+d` | App launcher |
| `Super+e` | Firefox |
| `Super+f` | Files |
| `Super+Left/Right` | Prev / next workspace |
| Edge swipe L/R | Prev / next workspace |
| Edge swipe down / up | Launcher / power menu |

## Topics

`first-look` · `desktop-sway` · `quick-menus` · `display-power` · `apps` ·
`emulation` · `networking` · `pager` · `maintenance`
