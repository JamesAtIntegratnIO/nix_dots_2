# Volume menu: mute, preset levels, output device, mic mute, pavucontrol.
# shellcheck source=/dev/null
source "$QUICKMENU_COMMON"

sink=@DEFAULT_AUDIO_SINK@
source=@DEFAULT_AUDIO_SOURCE@
vol=$(wpctl get-volume "$sink")
pct=$(awk '{ printf "%d", $2 * 100 + 0.5 }' <<<"$vol")
muted=false
[[ "$vol" == *MUTED* ]] && muted=true

rows=() acts=() active=()
if $muted; then
  rows+=("$(row "$QM_HOT" "$G_MUTE" "Unmute" "muted at $pct%")"); acts+=(mute)
else
  rows+=("$(row "$QM_ACCENT" "$G_VOL" "Mute" "$pct%")"); acts+=(mute)
fi

# Preset levels; the one nearest the current volume is highlighted.
nearest=""
best=1000
for p in 100 75 50 25 10; do
  d=$((p > pct ? p - pct : pct - p))
  [ "$d" -lt "$best" ] && { best=$d; nearest=$p; }
done
for p in 100 75 50 25 10; do
  [ "$p" = "$nearest" ] && active+=("${#rows[@]}")
  rows+=("$(row "$QM_DIM" "$G_VOL" "$p%")"); acts+=("level:$p")
done

# Output devices (PipeWire sinks); the default one is highlighted.
default_name=$(pw-dump | jq -r '.[] | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default") | .metadata[] | select(.key == "default.audio.sink") | .value.name' | head -1)
current_desc=""
while IFS=$'\t' read -r id name desc; do
  if [ "$name" = "$default_name" ]; then active+=("${#rows[@]}"); current_desc=$desc; fi
  rows+=("$(row "$QM_ACCENT" "$G_HEAD" "$desc" "output")"); acts+=("sink:$id")
done < <(pw-dump | jq -r '.[] | select(.type == "PipeWire:Interface:Node" and .info.props["media.class"] == "Audio/Sink") | [.id, .info.props["node.name"], (.info.props["node.description"] // .info.props["node.name"])] | @tsv')

if wpctl get-volume "$source" >/dev/null 2>&1; then
  if [[ "$(wpctl get-volume "$source")" == *MUTED* ]]; then
    rows+=("$(row "$QM_HOT" "$G_MICOFF" "Unmute mic")"); acts+=(mic)
  else
    rows+=("$(row "$QM_OK" "$G_MIC" "Mute mic")"); acts+=(mic)
  fi
fi
rows+=("$(row "$QM_DIM" "$G_GEAR" "Advanced (pavucontrol)")"); acts+=(pavucontrol)

mesg="$pct%"
$muted && mesg="<span color=\"$QM_HOT\">muted</span> ($pct%)"
[ -n "$current_desc" ] && mesg="$mesg · $(esc "$current_desc")"
i=$(printf '%s\n' "${rows[@]}" | menu volume "$mesg" "$(IFS=,; echo "${active[*]}")")

case "${acts[$i]}" in
  mute) wpctl set-mute "$sink" toggle ;;
  level:*) wpctl set-mute "$sink" 0; wpctl set-volume "$sink" "${acts[$i]#level:}%" ;;
  sink:*) wpctl set-default "${acts[$i]#sink:}" ;;
  mic) wpctl set-mute "$source" toggle ;;
  pavucontrol) exec pavucontrol ;;
esac
