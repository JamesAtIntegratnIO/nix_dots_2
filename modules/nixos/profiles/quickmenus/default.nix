# Touch-friendly quick menus for the PocketTerm35, in the power-menu style
# (fuzzel dmenu, second tap closes). Opened from their Waybar modules (see
# ../cyberdeck) or Super+W / Super+B / Super+V:
#
#   netmenu  Wi-Fi: join (password prompt for new secured networks),
#            disconnect, rescan, radio toggle, nmtui fallback
#   btmenu   Bluetooth: power, 10s scan, connect/disconnect/pair+trust
#   volmenu  Volume: mute, preset levels, output device, mic mute, pavucontrol
{ pkgs, ... }:

let
  common = pkgs.writeText "quickmenu-common.sh" (builtins.readFile ./common.sh);

  quickmenu =
    name: inputs:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs =
        with pkgs;
        [
          fuzzel
          libnotify
          procps
          gawk
          gnugrep
        ]
        ++ inputs;
      runtimeEnv.QUICKMENU_COMMON = common;
      text = builtins.readFile (./. + "/${name}.sh");
    };

  netmenu = quickmenu "netmenu" [
    pkgs.networkmanager
    pkgs.foot
  ];
  btmenu = quickmenu "btmenu" [ pkgs.bluez ];
  volmenu = quickmenu "volmenu" (
    with pkgs;
    [
      wireplumber
      pipewire
      jq
      pavucontrol
    ]
  );
in
{
  environment.systemPackages = [
    netmenu
    btmenu
    volmenu
  ];

  environment.etc."sway/config.d/quickmenus.conf".text = ''
    bindsym $mod+w exec netmenu
    bindsym $mod+b exec btmenu
    bindsym $mod+v exec volmenu
  '';
}
