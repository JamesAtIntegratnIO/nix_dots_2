# Desktop (Sway)

A lean Wayland session: Sway + Waybar + rofi, themed by the cyberdeck palette.
No gaps or edge borders — every pixel on the 640x480 panel is content. **Super**
(Mod4) is the mod key.

## Launching things

| Keys | Action |
|------|--------|
| `Super+Return` | Terminal (foot) |
| `Super+d` | App launcher (rofi) — also swipe down from the top edge |
| `Super+e` | Firefox |
| `Super+f` | File manager (pcmanfm) |
| `Super+g` | RetroArch |
| `Super+q` | Close focused window |

## Power / session

| Keys | Action |
|------|--------|
| `Super+Shift+e` | Power menu (lock / log out / reboot / off) |
| `Super+Escape` | Power menu |
| Power button | Power menu (short press) |

## Screenshots

| Keys | Action |
|------|--------|
| `Super+s` | Whole screen → clipboard |
| `Super+Shift+s` | Region (drag to select) → clipboard |

Paste anywhere with `Ctrl+V`. (The primary selection is mirrored into the
clipboard too, so highlighting text is enough to paste it.)

## Volume (function-row keys)

- `XF86AudioRaiseVolume` / `LowerVolume` → ±5% via `wpctl`
- `XF86AudioMute` → toggle mute
- Fine control: `Super+v` volume menu, or `pavucontrol`.

## Workspaces

This deck is **one app per workspace** — tiling two windows on a 640x480 panel
is useless, so a new app opens on its own fresh workspace right after the one
you launched it from (handled by `wsd`).

| Keys | Action |
|------|--------|
| `Super+1..4` | Jump to workspace 1–4 |
| `Super+Shift+1..4` | Move current window to workspace 1–4 |
| `Super+Right` | Next workspace — past the last one **creates a new empty one** |
| `Super+Left` | Previous workspace — from workspace 1 **wraps to the last** |

Empty workspaces vanish when you leave them, so they never pile up.

## Gestures (edge swipes)

Swipes must **start at a screen edge** (in-app touch is never hijacked):

| Swipe | Action |
|-------|--------|
| Left edge → right | Previous workspace (`ws-nav prev`) |
| Right edge → left | Next workspace (`ws-nav next`) |
| Top edge → down | App launcher |
| Bottom edge → up | Power menu |

## Bar

Waybar sits at the top. Its Wi-Fi / Bluetooth / volume / power widgets open the
same quick menus described in *Quick menus*.
