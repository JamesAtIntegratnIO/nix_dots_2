# Power menu for the Hyprland session (Super+Shift+E, the bar's power button;
# Ctrl+Super+E while a RustDesk window has focus). Built on the PocketTerm's
# quick-menu helpers. Log out, Reboot and Power off ask again, so a stray key
# can't end the session the way the old instant exit did.
# shellcheck source=/dev/null
source "$QUICKMENU_COMMON"

G_MOON=$'\xef\x86\x86' G_SNOW=$'\xef\x8b\x9c' G_GAUGE=$'\xef\x83\xa4'

profile_menu() {
  local current names=(power-saver balanced performance) rows=() active="" n i
  current=$(powerprofilesctl get)
  for n in "${!names[@]}"; do
    if [ "${names[$n]}" = "$current" ]; then
      rows+=("$(row "$QM_OK" "$G_DOT" "${names[$n]}" "current")")
      active=$n
    else
      rows+=("$(row "$QM_DIM" "$G_RING" "${names[$n]}")")
    fi
  done
  i=$(printf '%s\n' "${rows[@]}" |
    menu profile "Plugging in or unplugging resets it" "$active") || return 0
  powerprofilesctl set "${names[$i]}"
  note "Power profile" "${names[$i]}"
}

up=$(uptime -p 2>/dev/null | sed 's/^up //')
i=$(printf '%s\n' \
  "$(row "$QM_ACCENT" "$G_LOCK" "Lock")" \
  "$(row "$QM_ACCENT" "$G_MOON" "Suspend" "hibernates after an hour")" \
  "$(row "$QM_ACCENT" "$G_SNOW" "Hibernate")" \
  "$(row "$QM_ACCENT" "$G_GAUGE" "Power profile" "$(powerprofilesctl get)")" \
  "$(row "$QM_WARN" "$G_LOGOUT" "Log out")" \
  "$(row "$QM_WARN" "$G_REBOOT" "Reboot")" \
  "$(row "$QM_HOT" "$G_POWER" "Power off")" |
  menu power "$(hostname) · up $(esc "$up")") || exit 0

case "$i" in
  0) loginctl lock-session ;;
  1) systemctl suspend-then-hibernate ;;
  2) systemctl hibernate ;;
  3) profile_menu ;;
  4) confirm "log out" && hyprctl dispatch 'hl.dsp.exit()' ;;
  5) confirm reboot && systemctl reboot ;;
  6) confirm "power off" && systemctl poweroff ;;
esac
