# Apps

Everything picked to make sense on a 640x480 handheld.

## GUI

| App | Launch | Notes |
|-----|--------|-------|
| **Firefox** | `Super+e` | Compact density, dark, no bookmarks bar. Pinch-zoom works. Handles the Pager UI. |
| **pcmanfm** (files) | `Super+f` | A single tap opens files/folders. |
| **mousepad** | tap a text file | Lightweight editor; default for text/markdown/json/yaml/toml/shell. |
| **imv** | tap an image | Image viewer (png/jpg/gif/webp/bmp/svg). |
| **zathura** | tap a PDF | PDF viewer. |
| **mpv** | tap a video/audio | Media player. |
| **pavucontrol** | run it | Full audio mixer when the volume menu isn't enough. |

Tapping a file opens it in the app above (xdg defaults). Web links open in
Firefox.

## Terminal (foot)

`Super+Return`. Slightly translucent, so the wallpaper glows through. Tips:

- **Highlight to copy**: select text and it copies to the clipboard too; `Ctrl+V`
  pastes anywhere.
- **Open a URL**: `Ctrl+click` it (or `Ctrl+Shift+u`, then the letter tag) to
  open it in Firefox.
- Colors come from the shared 16-slot palette.

## Terminal tools

- **yazi**: fast terminal file manager (lighter than pcmanfm on this screen).
- **btop**: system monitor (TTY theme; press `1`–`4` to toggle boxes).
- **bat**: `cat` with syntax highlight. **fd**: friendly `find`. **rg**: ripgrep.
- **fzf**: `Ctrl+R` history, `Ctrl+T` files, `Alt+C` cd. Fuzzy tab-completion on.
- **tmux**: mouse on (tap panes, scroll), status bar in the palette.
- **git**: uses `delta` as the pager (ANSI theme, line numbers).

## The wiki

You're reading it. `wiki` browses, `wiki <query>` searches, `wiki ls` lists.
