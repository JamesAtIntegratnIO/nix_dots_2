# Field-tools launcher (Super+T): the pentest/network tools from
# ../pentest.nix, each opened in a foot terminal. Keep in sync with it.
# shellcheck source=/dev/null
source "$QUICKMENU_COMMON"

# glyph|label|hint|command (run via foot; the command keeps the window open)
tools=(
  "$G_WIFI|Pineapple web UI|172.16.52.1:1471|firefox http://172.16.52.1:1471"
  "$G_SEARCH|nmap|ping-sweep the Pager subnet|nmap -sn 172.16.52.0/24"
  "$G_SEARCH|arp-scan|local network|sudo arp-scan --localnet"
  "$G_WIFI|kismet|wireless monitor|kismet"
  "$G_WIFI|iw dev|wireless interfaces|iw dev"
  "$G_TERM|tcpdump|all interfaces|sudo tcpdump -i any -n"
  "$G_TERM|termshark|terminal Wireshark|termshark"
  "$G_REBOOT|mtr|trace to 1.1.1.1|mtr 1.1.1.1"
  "$G_REBOOT|iperf3 server|throughput test|iperf3 -s"
  "$G_TERM|serial console|tio /dev/ttyUSB0|tio /dev/ttyUSB0"
  "$G_GEAR|i2c buses|i2cdetect -l|i2cdetect -l"
  "$G_GEAR|usb devices|lsusb|lsusb"
  "$G_GEAR|btop|processes|btop"
)

rows=()
for t in "${tools[@]}"; do
  IFS='|' read -r glyph label hint _ <<<"$t"
  rows+=("$(row "$QM_ACCENT" "$glyph" "$label" "$hint")")
done
i=$(printf '%s\n' "${rows[@]}" | menu tools)
IFS='|' read -r _ label _ cmd <<<"${tools[$i]}"

case "$cmd" in
  firefox*) read -ra argv <<<"$cmd"; exec "${argv[@]}" ;;
  *) exec foot -a toolrun -T "$label" sh -c "$cmd; echo; read -rp '[enter to close] ' _" ;;
esac
