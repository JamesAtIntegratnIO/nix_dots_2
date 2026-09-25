# Power menu (bar button, Super+Shift+E, Super+Escape, the Pi's power
# button). Everything but Lock asks again, so a stray tap can't power off.
# shellcheck source=/dev/null
source "$QUICKMENU_COMMON"

up=$(uptime -p 2>/dev/null | sed 's/^up //')
if [ "$(pwrmode status)" = saver ]; then
  saver_row=$(row "$QM_OK" "$G_BATT" "Battery saver" "on")
else
  saver_row=$(row "$QM_DIM" "$G_BATT" "Battery saver" "off")
fi
i=$(printf '%s\n' \
  "$(row "$QM_ACCENT" "$G_LOCK" "Lock")" \
  "$(row "$QM_WARN" "$G_LOGOUT" "Log out")" \
  "$(row "$QM_WARN" "$G_REBOOT" "Reboot")" \
  "$(row "$QM_HOT" "$G_POWER" "Power off")" \
  "$saver_row" |
  menu power "$(hostname) · up $(esc "$up")") || exit 0

case "$i" in
  0) swaylock -f -C /etc/swaylock/config ;;
  1) confirm "log out" && swaymsg exit ;;
  2) confirm reboot && systemctl reboot ;;
  3) confirm "power off" && systemctl poweroff ;;
  4)
    pwrmode toggle
    note "Battery saver $([ "$(pwrmode status)" = saver ] && echo on || echo off)" \
      "$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor) governor"
    ;;
esac
