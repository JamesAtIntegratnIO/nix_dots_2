# Wi-Fi menu: networks by signal (current one highlighted), join with a
# masked password prompt for new secured networks, disconnect, rescan, radio
# toggle, nmtui fallback.
# shellcheck source=/dev/null
source "$QUICKMENU_COMMON"

bars() { # signal 0-100 -> 4-step bar
  local s=$1
  if [ "$s" -ge 75 ]; then printf '▂▄▆█'
  elif [ "$s" -ge 50 ]; then printf '▂▄▆_'
  elif [ "$s" -ge 25 ]; then printf '▂▄__'
  else printf '▂___'
  fi
}

rows=() acts=() active=()
current=""
if [ "$(nmcli -t -f WIFI general)" = enabled ]; then
  declare -A seen secure
  # IN-USE:SIGNAL:SECURITY:SSID -- SSID last so colons in names survive.
  while IFS=: read -r inuse signal security ssid; do
    [ -n "$ssid" ] && [ -z "${seen[$ssid]+x}" ] || continue
    seen[$ssid]=1
    lock=""
    if [ -n "$security" ] && [ "$security" != "--" ]; then lock="  $G_LOCK"; secure[$ssid]=1; fi
    [ "$inuse" = "*" ] && { current=$ssid; active+=("${#rows[@]}"); }
    color=$QM_DIM
    [ "$signal" -ge 50 ] && color=$QM_ACCENT
    rows+=("$(row "$color" "$G_WIFI" "$ssid" "$(bars "$signal") $signal%$lock")")
    acts+=("net:$ssid")
  done < <(nmcli -t --escape no -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no | sort -t: -k2,2nr)

  [ -n "$current" ] && { rows+=("$(row "$QM_WARN" "$G_UNLINK" "Disconnect")"); acts+=(disconnect); }
  rows+=("$(row "$QM_ACCENT" "$G_REBOOT" "Rescan")"); acts+=(rescan)
  rows+=("$(row "$QM_OK" "$G_ON" "Wi-Fi on" "tap to turn off")"); acts+=(radio-off)
  if [ -n "$current" ]; then
    ip=$(nmcli -g IP4.ADDRESS device show "$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2 == "wifi" { print $1; exit }')" | head -1)
    mesg="connected to <b>$(esc "$current")</b>${ip:+ · $ip}"
  else
    mesg="not connected"
  fi
else
  rows+=("$(row "$QM_DIM" "$G_OFF" "Wi-Fi is off" "tap to turn on")"); acts+=(radio-on)
  mesg="radio off"
fi
rows+=("$(row "$QM_DIM" "$G_TERM" "Advanced (nmtui)")"); acts+=(nmtui)

i=$(printf '%s\n' "${rows[@]}" | menu wifi "$mesg" "$(IFS=,; echo "${active[*]}")")

case "${acts[$i]}" in
  radio-on) nmcli radio wifi on && note "Wi-Fi" "on" ;;
  radio-off) nmcli radio wifi off && note "Wi-Fi" "off" ;;
  rescan)
    note "Wi-Fi" "scanning..."
    nmcli device wifi rescan 2>/dev/null || true
    sleep 3
    exec "$0"
    ;;
  disconnect) nmcli connection down id "$current" >/dev/null && note "Wi-Fi" "disconnected from $current" ;;
  nmtui) exec foot -a nmtui nmtui ;;
  net:*)
    ssid=${acts[$i]#net:}
    [ "$ssid" = "$current" ] && exit 0
    if nmcli -t -f NAME connection show | grep -Fxq -- "$ssid"; then
      cmd=(nmcli connection up id "$ssid")
    elif [ -n "${secure[$ssid]+x}" ]; then
      pw=$(ask "$ssid password" password)
      [ -n "$pw" ] || exit 0
      cmd=(nmcli device wifi connect "$ssid" password "$pw")
    else
      cmd=(nmcli device wifi connect "$ssid")
    fi
    note "Wi-Fi" "connecting to $ssid..."
    if out=$("${cmd[@]}" 2>&1); then note "Wi-Fi" "connected to $ssid"; else note "Wi-Fi failed" "$out"; fi
    ;;
esac
