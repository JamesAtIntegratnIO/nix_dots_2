# Bluetooth menu, modelled on rofi-bluetooth: controller toggles + a device
# list on the main menu; each device opens its own connect/pair/trust/remove
# menu. `btmenu MAC` opens a device's menu directly (used to come back to it
# after an action).
# shellcheck source=/dev/null
source "$QUICKMENU_COMMON"

show=$(bluetoothctl show)
flag() { grep -q "$1: yes" <<<"$2"; }

device_icon() { # from the Icon: field of `bluetoothctl info`
  case "$(awk '/Icon:/ { print $2; exit }' <<<"$1")" in
    audio-*) printf '%s' "$G_HEAD" ;;
    input-keyboard) printf '%s' "$G_KBD" ;;
    input-mouse | input-tablet | input-gaming) printf '%s' "$G_MOUSE" ;;
    phone) printf '%s' "$G_PHONE" ;;
    *) printf '%s' "$G_BT" ;;
  esac
}

battery() { # "85%" if the device reports it
  awk -F'[()]' '/Battery Percentage/ { print $2 "%"; exit }' <<<"$1"
}

device_menu() {
  local mac=$1 info name state=() rows=() acts=() i
  info=$(bluetoothctl info "$mac") || exit 0
  name=$(awk -F': ' '/\tAlias:/ { print $2; exit }' <<<"$info")
  flag Connected "$info" && state+=("connected")
  flag Paired "$info" && state+=("paired")
  flag Trusted "$info" && state+=("trusted")
  [ -n "$(battery "$info")" ] && state+=("battery $(battery "$info")")

  if flag Connected "$info"; then
    rows+=("$(row "$QM_WARN" "$G_UNLINK" "Disconnect")"); acts+=(disconnect)
  else
    rows+=("$(row "$QM_OK" "$G_LINK" "Connect")"); acts+=(connect)
  fi
  if flag Paired "$info"; then
    rows+=("$(row "$QM_HOT" "$G_TRASH" "Remove" "unpair and forget")"); acts+=(remove)
  else
    rows+=("$(row "$QM_ACCENT" "$G_PAIR" "Pair" "pair, trust and connect")"); acts+=(pair)
    rows+=("$(row "$QM_DIM" "$G_TERM" "Pair in terminal" "for devices that show a PIN")"); acts+=(pair-term)
  fi
  if flag Trusted "$info"; then
    rows+=("$(row "$QM_DIM" "$G_SHIELD" "Untrust")"); acts+=(untrust)
  else
    rows+=("$(row "$QM_ACCENT" "$G_SHIELD" "Trust" "reconnect automatically")"); acts+=(trust)
  fi
  rows+=("$(row "$QM_DIM" "$G_BACK" "Back")"); acts+=(back)

  local mesg="$mac" s
  for s in "${state[@]}"; do mesg+=" · $s"; done
  i=$(printf '%s\n' "${rows[@]}" | menu "$name" "$(esc "$mesg")") || exit 0

  case "${acts[$i]}" in
    connect)
      note "Bluetooth" "connecting $name..."
      if bluetoothctl connect "$mac" >/dev/null; then note "Bluetooth" "connected $name"
      else note "Bluetooth failed" "couldn't connect $name"; fi
      ;;
    disconnect) bluetoothctl disconnect "$mac" >/dev/null && note "Bluetooth" "disconnected $name" ;;
    pair)
      note "Bluetooth" "pairing $name..."
      if bluetoothctl pair "$mac" >/dev/null && bluetoothctl trust "$mac" >/dev/null &&
        bluetoothctl connect "$mac" >/dev/null; then
        note "Bluetooth" "paired and connected $name"
      else
        note "Bluetooth failed" "couldn't pair $name -- try 'Pair in terminal'"
      fi
      ;;
    pair-term)
      note "Bluetooth" "in bluetoothctl, type: pair $mac"
      exec foot -a bluetoothctl bluetoothctl
      ;;
    remove) bluetoothctl remove "$mac" >/dev/null && note "Bluetooth" "removed $name" && exec "$0" ;;
    trust) bluetoothctl trust "$mac" >/dev/null ;;
    untrust) bluetoothctl untrust "$mac" >/dev/null ;;
    back) exec "$0" ;;
  esac
  exec "$0" "$mac" # back to this device's menu with fresh state
}

if [ -n "${1:-}" ]; then device_menu "$1"; fi

# Order: devices and scan first, the power toggle last -- the first row is
# pre-selected, so an accidental Enter must never turn Bluetooth off.
rows=() acts=() active=()
if ! flag Powered "$show"; then
  rows+=("$(row "$QM_DIM" "$G_OFF" "Bluetooth is off" "tap to turn on")"); acts+=(power-on)
else
  # Devices: connected first, then paired, then everything else seen.
  declare -a conn=() paired=() other=()
  while read -r _ mac _; do
    info=$(bluetoothctl info "$mac")
    name=$(awk -F': ' '/\tAlias:/ { print $2; exit }' <<<"$info")
    bat=$(battery "$info")
    if flag Connected "$info"; then conn+=("$mac|$name|connected${bat:+ · $bat}|$(device_icon "$info")")
    elif flag Paired "$info"; then paired+=("$mac|$name|paired${bat:+ · $bat}|$(device_icon "$info")")
    else other+=("$mac|$name||$(device_icon "$info")")
    fi
  done < <(bluetoothctl devices)
  for d in "${conn[@]}" "${paired[@]}" "${other[@]}"; do
    IFS='|' read -r mac name status icon <<<"$d"
    [[ "$status" == connected* ]] && active+=("${#rows[@]}")
    color=$QM_DIM
    [ -n "$status" ] && color=$QM_ACCENT
    rows+=("$(row "$color" "$icon" "$name" "$status")"); acts+=("dev:$mac")
  done

  if flag Discovering "$show"; then
    rows+=("$(row "$QM_WARN" "$G_SEARCH" "Stop scanning")"); acts+=(scan-off)
    rows+=("$(row "$QM_ACCENT" "$G_REBOOT" "Refresh list")"); acts+=(refresh)
  else
    rows+=("$(row "$QM_ACCENT" "$G_SEARCH" "Scan for devices")"); acts+=(scan-on)
  fi
  if flag Pairable "$show"; then
    rows+=("$(row "$QM_OK" "$G_ON" "Pairable")"); acts+=(pairable-off)
  else
    rows+=("$(row "$QM_DIM" "$G_OFF" "Pairable")"); acts+=(pairable-on)
  fi
  if flag Discoverable "$show"; then
    rows+=("$(row "$QM_OK" "$G_EYE" "Discoverable")"); acts+=(discoverable-off)
  else
    rows+=("$(row "$QM_DIM" "$G_EYE" "Discoverable")"); acts+=(discoverable-on)
  fi
  rows+=("$(row "$QM_OK" "$G_ON" "Bluetooth on" "tap to turn off")"); acts+=(power-off)
fi
rows+=("$(row "$QM_DIM" "$G_TERM" "bluetoothctl")"); acts+=(terminal)

controller=$(awk '/Name:/ { sub(/.*Name: /, ""); print; exit }' <<<"$show")
mesg="$(esc "${controller:-no controller}")"
flag Discovering "$show" && mesg="$mesg · <span color=\"$QM_WARN\">scanning...</span>"
i=$(printf '%s\n' "${rows[@]}" | menu bluetooth "$mesg" "$(IFS=,; echo "${active[*]}")") || exit 0

case "${acts[$i]}" in
  power-on) bluetoothctl power on >/dev/null ;;
  power-off) bluetoothctl power off >/dev/null ;;
  scan-on)
    # BlueZ ties discovery to the client that started it, so a background
    # bluetoothctl holds it; "Stop scanning" kills that process.
    nohup bluetoothctl --timeout 30 scan on >/dev/null 2>&1 &
    sleep 4
    ;;
  scan-off) pkill -f '[b]luetoothctl --timeout 30 scan on' || true ;;
  refresh) ;;
  pairable-on) bluetoothctl pairable on >/dev/null ;;
  pairable-off) bluetoothctl pairable off >/dev/null ;;
  discoverable-on) bluetoothctl discoverable on >/dev/null ;;
  discoverable-off) bluetoothctl discoverable off >/dev/null ;;
  terminal) exec foot -a bluetoothctl bluetoothctl ;;
  dev:*) exec "$0" "${acts[$i]#dev:}" ;;
esac
exec "$0"
