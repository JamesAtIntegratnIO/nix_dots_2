# Volume menu: mute, preset levels, output device, mic mute, pavucontrol.
# shellcheck source=/dev/null
source "$QUICKMENU_COMMON"

sink=@DEFAULT_AUDIO_SINK@
source=@DEFAULT_AUDIO_SOURCE@
vol=$(wpctl get-volume "$sink")
pct=$(awk '{ printf "%d", $2 * 100 + 0.5 }' <<<"$vol")
muted=""
[[ "$vol" == *MUTED* ]] && muted=" (muted)"

declare -A id_of
entries=()
if [ -n "$muted" ]; then entries+=("Unmute  $pct%"); else entries+=("Mute  $pct%"); fi
for p in 100 75 50 25 10; do entries+=("$p%"); done

# Output devices (PipeWire sinks), current one marked.
default_name=$(pw-dump | jq -r '.[] | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default") | .metadata[] | select(.key == "default.audio.sink") | .value.name' | head -1)
while IFS=$'\t' read -r id name desc; do
  mark="  "
  [ "$name" = "$default_name" ] && mark="● "
  label="${mark}Output: $desc"
  id_of[$label]=$id
  entries+=("$label")
done < <(pw-dump | jq -r '.[] | select(.type == "PipeWire:Interface:Node" and .info.props["media.class"] == "Audio/Sink") | [.id, .info.props["node.name"], (.info.props["node.description"] // .info.props["node.name"])] | @tsv')

if wpctl get-volume "$source" >/dev/null 2>&1; then
  if [[ "$(wpctl get-volume "$source")" == *MUTED* ]]; then entries+=("Mic: unmute"); else entries+=("Mic: mute"); fi
fi
entries+=("Advanced (pavucontrol)")

choice=$(printf '%s\n' "${entries[@]}" | menu "volume $pct%$muted" 12) || exit 0

case "$choice" in
  Mute* | Unmute*) wpctl set-mute "$sink" toggle ;;
  *%) wpctl set-mute "$sink" 0; wpctl set-volume "$sink" "${choice%\%}%" ;;
  "Mic: "*) wpctl set-mute "$source" toggle ;;
  "Advanced (pavucontrol)") exec pavucontrol ;;
  *)
    id=${id_of[$choice]:-}
    [ -n "$id" ] && wpctl set-default "$id" && note "Audio" "output: ${choice#*Output: }"
    ;;
esac
