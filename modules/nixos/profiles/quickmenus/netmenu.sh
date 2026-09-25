# Wi-Fi menu: join/leave networks, rescan, radio toggle, nmtui fallback.
# shellcheck source=/dev/null
source "$QUICKMENU_COMMON"

wifi=$(nmcli -t -f WIFI general)
current=$(nmcli -t -f ACTIVE,SSID device wifi list --rescan no 2>/dev/null | awk -F: '$1 == "yes" { sub(/^yes:/, ""); print; exit }')

# nf-fa-lock, as raw UTF-8 bytes: Private Use Area glyphs get stripped from
# source files by editors and tools.
lock_glyph=$'\xef\x80\xa3'

declare -A ssid_of
entries=()
if [ "$wifi" = enabled ]; then
  # IN-USE:SIGNAL:SECURITY:SSID with SSID last, so colons in names survive.
  while IFS=: read -r inuse signal security ssid; do
    [ -n "$ssid" ] || continue
    [ -z "${ssid_of[$ssid]+x}" ] || continue
    lock=""
    [ -n "$security" ] && [ "$security" != "--" ] && lock="  $lock_glyph"
    mark="  "
    [ "$inuse" = "*" ] && mark="● "
    label=$(printf '%s%s  %s%%%s' "$mark" "$ssid" "$signal" "$lock")
    ssid_of[$ssid]=1
    ssid_of["label:$label"]=$ssid
    entries+=("$label")
  done < <(nmcli -t --escape no -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no | sort -t: -k2,2nr)
  [ -n "$current" ] && entries+=("Disconnect $current")
  entries+=("Rescan" "Wi-Fi off")
else
  entries+=("Wi-Fi on")
fi
entries+=("Advanced (nmtui)")

choice=$(printf '%s\n' "${entries[@]}" | menu wifi 10) || exit 0

case "$choice" in
  "Wi-Fi on") nmcli radio wifi on && note "Wi-Fi" "on" ;;
  "Wi-Fi off") nmcli radio wifi off && note "Wi-Fi" "off" ;;
  Rescan)
    note "Wi-Fi" "scanning..."
    nmcli device wifi rescan 2>/dev/null || true
    sleep 3
    exec "$0"
    ;;
  "Disconnect "*)
    nmcli connection down id "$current" >/dev/null && note "Wi-Fi" "disconnected from $current"
    ;;
  "Advanced (nmtui)") exec foot -a nmtui nmtui ;;
  *)
    ssid=${ssid_of["label:$choice"]:-}
    [ -n "$ssid" ] || exit 0
    if nmcli -t -f NAME connection show | grep -Fxq -- "$ssid"; then
      cmd=(nmcli connection up id "$ssid")
    elif [[ "$choice" == *"$lock_glyph"* ]]; then
      pw=$(fuzzel --dmenu --password --prompt "$ssid password ❯ " --lines 0 --width 32) || exit 0
      [ -n "$pw" ] || exit 0
      cmd=(nmcli device wifi connect "$ssid" password "$pw")
    else
      cmd=(nmcli device wifi connect "$ssid")
    fi
    if out=$("${cmd[@]}" 2>&1); then
      note "Wi-Fi" "connected to $ssid"
    else
      note "Wi-Fi failed" "$out"
    fi
    ;;
esac
