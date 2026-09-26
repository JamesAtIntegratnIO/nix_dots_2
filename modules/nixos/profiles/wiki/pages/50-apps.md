# Apps

## GUI apps

| App | Keybind | Command | Handles |
|-----|---------|---------|---------|
| Firefox | `Super+e` | `firefox <url>` | Web, the Pager UI |
| pcmanfm | `Super+f` | `pcmanfm <dir>` | Files (single tap opens) |
| mousepad | - | `mousepad <file>` | Text / md / json / yaml / toml / sh |
| imv | - | `imv <image>` | png / jpg / gif / webp / bmp / svg |
| zathura | - | `zathura <file.pdf>` | PDF |
| mpv | - | `mpv <file>` | Video / audio |
| pavucontrol | - | `pavucontrol` | Audio mixer |
| Fractal | - | `fractal` | Matrix chat |

Tapping a file opens it in the app above (xdg defaults); web links open in
Firefox.

## Terminal (foot)

`Super+Return`. Highlight text to copy it (mirrored to clipboard), `Ctrl+V`
pastes. `Ctrl+click` a URL (or `Ctrl+Shift+u` then the letter) opens it in
Firefox.

## Terminal tools

    yazi                 # file manager (lighter than pcmanfm here)
    btop                 # system monitor; 1-4 toggle boxes
    rg PATTERN           # ripgrep search
    fd NAME              # find files
    bat FILE             # cat with syntax highlight
    delta                # git's pager (auto-used by `git diff`)

fzf bindings in the shell: `Ctrl+R` history, `Ctrl+T` files, `Alt+C` cd.
tmux: mouse on (tap panes, scroll).

## This wiki

    wiki                 # browse
    wiki <query>         # search
    wiki ls              # list topics
