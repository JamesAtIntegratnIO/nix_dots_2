# Shared by the quick menus (sourced, not run on its own): a rofi dmenu in the
# cyberdeck theme, markup helpers, notifications and a glyph table.
#
# Palette colors come from the environment (QM_*), set in default.nix from
# ../cyberdeck/palette.nix.

# A second tap on a bar button closes the open menu instead of stacking one.
# (An explicit if: a bare `pkill ... && exit` here makes `source` return 1
# when no menu is open, and errexit then kills the caller.)
if pkill -x rofi; then exit 0; fi

# Nerd Font glyphs as raw UTF-8 bytes. Private Use Area characters written
# literally get stripped from source files by editors and tools.
G_WIFI=$'\xef\x87\xab'   G_LOCK=$'\xef\x80\xa3'    G_BT=$'\xef\x8a\x93'
G_HEAD=$'\xef\x80\xa5'   G_KBD=$'\xef\x84\x9c'     G_MOUSE=$'\xef\x89\x85'
G_PHONE=$'\xef\x84\x8b'  G_VOL=$'\xef\x80\xa8'     G_MUTE=$'\xef\x80\xa6'
G_MIC=$'\xef\x84\xb0'    G_MICOFF=$'\xef\x84\xb1'  G_POWER=$'\xef\x80\x91'
G_LOGOUT=$'\xef\x82\x8b' G_REBOOT=$'\xef\x80\xa1'  G_SEARCH=$'\xef\x80\x82'
G_ON=$'\xef\x88\x85'     G_OFF=$'\xef\x88\x84'     G_LINK=$'\xef\x83\x81'
G_UNLINK=$'\xef\x84\xa7' G_TRASH=$'\xef\x87\xb8'   G_BACK=$'\xef\x81\xa0'
G_TERM=$'\xef\x84\xa0'   G_EYE=$'\xef\x81\xae'     G_SHIELD=$'\xef\x84\xb2'
G_BATT=$'\xef\x89\x80'   G_GEAR=$'\xef\x80\x93'    G_PAIR=$'\xef\x8a\xb5'
G_DOT=$'\xe2\x97\x8f'    G_RING=$'\xe2\x97\x8b'

# Escape text for Pango markup (SSIDs and device names can contain & < >).
esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' <<<"$1"; }

# A colored glyph followed by (escaped) text: row COLOR GLYPH TEXT [DIMTEXT]
row() {
  local out
  out="<span color=\"$1\">$2</span>  $(esc "$3")"
  [ -n "${4:-}" ] && out="$out  <span color=\"$QM_DIM\">$(esc "$4")</span>"
  printf '%s\n' "$out"
}

# menu PROMPT [MESSAGE] [ACTIVE_ROWS] [URGENT_ROWS]
# Rows (Pango markup) on stdin. Prints the chosen row's 0-based index; exits
# the script quietly if the menu is dismissed. ACTIVE/URGENT are rofi row
# lists like "0,3" and highlight rows (current network, connected device...).
menu() {
  local args=(-config /etc/rofi/config.rasi -dmenu -i -markup-rows -no-custom -format i -p "$1")
  [ -n "${2:-}" ] && args+=(-mesg "$2")
  [ -n "${3:-}" ] && args+=(-a "$3")
  [ -n "${4:-}" ] && args+=(-u "$4")
  rofi "${args[@]}" || exit 0
}

# ask PROMPT [password] -> typed text (masked when "password")
ask() {
  local args=(-config /etc/rofi/config.rasi -dmenu -p "$1" -l 0)
  [ "${2:-}" = password ] && args+=(-password)
  rofi "${args[@]}" </dev/null || exit 0
}

note() { notify-send -t 2500 "$1" "${2:-}"; }
