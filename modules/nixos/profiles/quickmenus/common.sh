# Shared by the quick menus: a fuzzel dmenu in the power-menu style, and a
# short notification. Sourced; not run on its own.
menu() { # prompt lines
  fuzzel --dmenu --prompt "$1 ❯ " --lines "$2" --width 32
}
note() {
  notify-send -t 2500 "$1" "${2:-}"
}
# A second tap on the bar button closes an open menu instead of stacking one.
# (An explicit if: a bare `pkill ... && exit` as the file's last line makes
# `source` return 1 when no menu is open, and errexit then kills the caller.)
if pkill -x fuzzel; then exit 0; fi
