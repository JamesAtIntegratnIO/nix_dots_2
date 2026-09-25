# Desktop (Sway)

Sway + Waybar + rofi. No gaps or borders (every pixel counts on 640x480).
**Super** (Mod4) is the mod key.

## Key bindings

| Keys | Action |
|------|--------|
| `Super+Return` | Terminal (foot) |
| `Super+d` | App launcher (or swipe down from top edge) |
| `Super+e` | Firefox |
| `Super+f` | Files (pcmanfm) |
| `Super+g` | RetroArch |
| `Super+q` | Close window |
| `Super+Shift+e` / `Super+Escape` | Power menu |
| `Super+s` | Whole screen to clipboard |
| `Super+Shift+s` | Region to clipboard |
| `Super+1..4` | Go to workspace 1–4 |
| `Super+Shift+1..4` | Move window to workspace 1–4 |
| `Super+Left` / `Super+Right` | Prev / next workspace |
| `Super+w` / `Super+b` / `Super+v` / `Super+t` | Wi-Fi / Bluetooth / volume / tools menu |
| `Super+minus` / `Super+equal` / `Super+0` | Dim / brighten / reset overlay |

## Gestures (swipe from a screen edge)

| Swipe | Action |
|-------|--------|
| Left edge → right | Previous workspace |
| Right edge → left | Next workspace |
| Top edge → down | App launcher |
| Bottom edge → up | Power menu |

## Same actions from the shell

    # Workspaces
    swaymsg workspace number 3
    swaymsg move container to workspace number 2
    ws-nav next            # next ws; past the last, opens a new empty one
    ws-nav prev            # prev ws; from ws 1, wraps to the last
    swaymsg -t get_workspaces

    # Screenshots
    grim ~/shot.png                     # whole screen to file
    grim -g "$(slurp)" ~/region.png     # region to file
    grim - | wl-copy                    # whole screen to clipboard

    # Volume (function-row keys do these too)
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    wpctl set-mute   @DEFAULT_AUDIO_SINK@ toggle

    # Windows / layout
    swaymsg -t get_tree | less          # inspect the tree
    swaymsg kill                        # close focused window

Clipboard: the primary selection mirrors into the clipboard, so highlighting
text is enough to `Ctrl+V` it anywhere.

## Layout model

One app per workspace (`wsd`): a new app opens on its own fresh workspace after
the current one. Empty workspaces disappear when you leave them.
