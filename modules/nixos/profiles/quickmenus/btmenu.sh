# Bluetooth menu: power, scan, and connect/disconnect/pair devices.
# shellcheck source=/dev/null
source "$QUICKMENU_COMMON"

powered=$(bluetoothctl show | awk '/Powered:/ { print $2; exit }')

declare -A mac_of
entries=()
if [ "$powered" = yes ]; then
  while read -r _ mac name; do
    info=$(bluetoothctl info "$mac")
    if grep -q "Connected: yes" <<<"$info"; then mark="● "
    elif grep -q "Paired: yes" <<<"$info"; then mark="○ "
    else mark="+ "
    fi
    label="$mark$name"
    mac_of[$label]=$mac
    entries+=("$label")
  done < <(bluetoothctl devices)
  entries+=("Scan (10s)" "Bluetooth off")
else
  entries+=("Bluetooth on")
fi

choice=$(printf '%s\n' "${entries[@]}" | menu bluetooth 10) || exit 0

case "$choice" in
  "Bluetooth on") bluetoothctl power on >/dev/null && note "Bluetooth" "on" ;;
  "Bluetooth off") bluetoothctl power off >/dev/null && note "Bluetooth" "off" ;;
  "Scan (10s)")
    note "Bluetooth" "scanning for 10s..."
    bluetoothctl --timeout 10 scan on >/dev/null 2>&1 || true
    exec "$0"
    ;;
  *)
    mac=${mac_of[$choice]:-}
    [ -n "$mac" ] || exit 0
    name=${choice#* } # drop the status mark
    case "$choice" in
      "● "*) bluetoothctl disconnect "$mac" >/dev/null && note "Bluetooth" "disconnected $name" ;;
      "○ "*)
        if bluetoothctl connect "$mac" >/dev/null; then note "Bluetooth" "connected $name"
        else note "Bluetooth failed" "couldn't connect $name"; fi
        ;;
      *)
        note "Bluetooth" "pairing $name..."
        if bluetoothctl pair "$mac" >/dev/null && bluetoothctl trust "$mac" >/dev/null &&
          bluetoothctl connect "$mac" >/dev/null; then
          note "Bluetooth" "paired and connected $name"
        else
          note "Bluetooth failed" "couldn't pair $name (devices that need a PIN: use bluetoothctl)"
        fi
        ;;
    esac
    ;;
esac
