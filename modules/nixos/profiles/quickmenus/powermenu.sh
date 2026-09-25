# Power menu (bar button, Super+Shift+E, Super+Escape, the Pi's power
# button). Everything but Lock asks again, so a stray tap can't power off.
# shellcheck source=/dev/null
source "$QUICKMENU_COMMON"

confirm() { # confirm WHAT -> succeeds only on an explicit yes
  local i
  i=$(printf '%s\n' "$(row "$QM_DIM" "$G_BACK" "No")" "$(row "$QM_HOT" "$G_POWER" "Yes, $1")" |
    menu "$1?")
  [ "$i" = 1 ]
}

up=$(uptime -p 2>/dev/null | sed 's/^up //')
i=$(printf '%s\n' \
  "$(row "$QM_ACCENT" "$G_LOCK" "Lock")" \
  "$(row "$QM_WARN" "$G_LOGOUT" "Log out")" \
  "$(row "$QM_WARN" "$G_REBOOT" "Reboot")" \
  "$(row "$QM_HOT" "$G_POWER" "Power off")" |
  menu power "$(hostname) · up $(esc "$up")")

case "$i" in
  0) swaylock -f -C /etc/swaylock/config ;;
  1) confirm "log out" && swaymsg exit ;;
  2) confirm reboot && systemctl reboot ;;
  3) confirm "power off" && systemctl poweroff ;;
esac
