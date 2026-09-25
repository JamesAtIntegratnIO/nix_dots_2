# A fuzzel menu of the field/network tools from ../pentest.nix, so they're
# reachable by touch without typing. Each entry opens in a foot terminal (the
# tools are all TUI/CLI). Bound to Super+t; also runnable as `toolmenu` and
# listed in fuzzel.
{ pkgs, ... }:

let
  # label -> command run in a foot terminal. Grouped by the comments in
  # pentest.nix; keep in sync when tools are added there.
  entries = {
    "Pineapple web UI" = "firefox http://172.16.52.1:1471";
    "nmap (subnet)" = "nmap -sn 172.16.52.0/24";
    "kismet" = "kismet";
    "aircrack-ng suite" = "aircrack-ng --help | less";
    "iw dev" = "iw dev";
    "arp-scan (local)" = "arp-scan --localnet";
    "tcpdump" = "tcpdump -i any -n";
    "termshark" = "termshark";
    "mtr" = "mtr 1.1.1.1";
    "iperf3 server" = "iperf3 -s";
    "serial console (tio)" = "tio /dev/ttyUSB0";
    "i2c buses" = "i2cdetect -l";
    "usb devices" = "lsusb";
    "htop" = "btop";
  };

  toolmenu = pkgs.writeShellApplication {
    name = "toolmenu";
    runtimeInputs = with pkgs; [
      fuzzel
      foot
      gnused
    ];
    text = ''
      pkill -x fuzzel && exit 0
      choice=$(
        cat <<'MENU' | fuzzel --dmenu --prompt "tools ❯ " --lines 12 --width 26
      ${builtins.concatStringsSep "\n" (builtins.attrNames entries)}
      MENU
      ) || exit 0

      case "$choice" in
      ${builtins.concatStringsSep "\n" (
        pkgs.lib.mapAttrsToList (
          label: cmd: "${pkgs.lib.escapeShellArg label}) foot -a toolrun ${cmd} ;;"
        ) entries
      )}
      esac
    '';
  };
in
{
  environment.systemPackages = [ toolmenu ];
}
