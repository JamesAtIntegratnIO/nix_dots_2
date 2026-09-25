# Phone-style workspaces for the 640x480 PocketTerm35, where tiling two apps
# side by side is useless:
#
# - wsd (./wsd.py) gives every new app its own workspace, inserted right after
#   the one it was launched from, and keeps the numbering gap-free.
# - ws-nav moves left/right: right past the last workspace opens a new empty
#   one, left from workspace 1 wraps around to the last.
#
# Bound to Super+Left/Right here; the edge-swipe gestures in
# ../wayland-kiosk.nix call ws-nav too.
{ pkgs, ... }:

let
  wsd = pkgs.writers.writePython3Bin "wsd" {
    libraries = [ pkgs.python3Packages.i3ipc ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./wsd.py);

  ws-nav = pkgs.writeShellApplication {
    name = "ws-nav";
    runtimeInputs = with pkgs; [
      sway
      jq
    ];
    text = ''
      wss=$(swaymsg -t get_workspaces)
      cur=$(jq '.[] | select(.focused) | .num' <<<"$wss")

      case "''${1:-}" in
        next)
          # Next existing workspace, or a new empty one past the end. An empty
          # workspace disappears when left, so this never piles up empties.
          target=$(jq --argjson c "$cur" '[.[].num | select(. > $c)] | min // ($c + 1)' <<<"$wss")
          ;;
        prev)
          # Previous workspace, wrapping from the first to the last.
          target=$(jq --argjson c "$cur" '([.[].num] | max) as $last | [.[].num | select(. < $c)] | max // $last' <<<"$wss")
          ;;
        *)
          echo "usage: ws-nav next|prev" >&2
          exit 2
          ;;
      esac

      [ "$target" = "$cur" ] || swaymsg -q "workspace number $target"
    '';
  };
in
{
  environment.systemPackages = [
    wsd
    ws-nav
  ];

  environment.etc."sway/config.d/workspaces.conf".text = ''
    exec ${wsd}/bin/wsd
    bindsym $mod+Right exec ws-nav next
    bindsym $mod+Left exec ws-nav prev
  '';
}
