# Touch-friendly quick menus for the PocketTerm35, all rofi in the shared
# cyberdeck theme (/etc/rofi/config.rasi, see ../cyberdeck/rofi.nix). Each
# returns rows by index, so labels are free-form Pango markup; a second call
# closes an open menu instead of stacking one.
#
#   netmenu    Wi-Fi: join (masked password for new secured networks),
#              disconnect, rescan, radio toggle, nmtui       (Super+W, bar)
#   btmenu     Bluetooth, modelled on rofi-bluetooth: power/scan/pairable/
#              discoverable + devices; per-device connect/pair/trust/remove
#                                                           (Super+B, bar)
#   volmenu    Volume: mute, levels, output device, mic mute (Super+V, bar)
#   powermenu  Lock / log out / reboot / power off, confirmed (Super+Shift+E,
#              Super+Escape, bar, power button, bottom swipe)
#   toolmenu   Field tools from ../pentest.nix                (Super+T)
{ pkgs, ... }:

let
  p = import ../cyberdeck/palette.nix;
  common = pkgs.writeText "quickmenu-common.sh" (builtins.readFile ./common.sh);

  quickmenu =
    name: inputs:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs =
        with pkgs;
        [
          rofi
          libnotify
          procps
          gawk
          gnugrep
          gnused
        ]
        ++ inputs;
      runtimeEnv = {
        QUICKMENU_COMMON = common;
        QM_ACCENT = "#${p.cyan}";
        QM_OK = "#${p.green}";
        QM_WARN = "#${p.amber}";
        QM_HOT = "#${p.magenta}";
        QM_DIM = "#${p.subtext}";
      };
      text = builtins.readFile (./. + "/${name}.sh");
    };
in
{
  environment.systemPackages = [
    (quickmenu "netmenu" (
      with pkgs;
      [
        networkmanager
        foot
      ]
    ))
    (quickmenu "btmenu" (
      with pkgs;
      [
        bluez
        foot
      ]
    ))
    (quickmenu "volmenu" (
      with pkgs;
      [
        wireplumber
        pipewire
        jq
        pavucontrol
      ]
    ))
    (quickmenu "powermenu" (
      with pkgs;
      [
        swaylock
        sway
        systemd
        nettools
      ]
    ))
    (quickmenu "toolmenu" [ pkgs.foot ])
  ];

  environment.etc."sway/config.d/quickmenus.conf".text = ''
    bindsym $mod+w exec netmenu
    bindsym $mod+b exec btmenu
    bindsym $mod+v exec volmenu
    bindsym $mod+t exec toolmenu
  '';
}
