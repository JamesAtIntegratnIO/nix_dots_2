# Extra-dim below the PocketTerm35 backlight's hardware floor.
#
# The keyboard's RP2040 drives the backlight PWM (Fn+brightness) and bottoms
# out at a level that's still too bright at night -- PWM frequency makes no
# difference, it's a floor in the backlight circuit. Gamma dimming isn't an
# option either: vc4 exposes no GAMMA_LUT, so wl-gammarelay-rs/wlsunset fail.
# So a click-through black layer-shell overlay (./overlay.py) scales the image
# down instead: Super+- / Super+= step it x0.75, Super+0 resets.
#
# This is comfort only -- it doesn't save power (the LEDs stay at whatever the
# backlight is set to). Turn the hardware backlight down first for battery.
{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [
    ps.pygobject3
    ps.pycairo
  ]);

  overlay = pkgs.stdenv.mkDerivation {
    pname = "screen-dim-overlay";
    version = "1";
    dontUnpack = true;
    nativeBuildInputs = with pkgs; [
      wrapGAppsHook3
      gobject-introspection
    ];
    buildInputs = with pkgs; [
      gtk3
      gtk-layer-shell
    ];
    installPhase = ''
      install -Dm755 ${./overlay.py} $out/bin/screen-dim-overlay
      sed -i '1i #!${python}/bin/python3' $out/bin/screen-dim-overlay
    '';
    # gtk-layer-shell has to be loaded before libwayland-client, which Python
    # can't guarantee on its own.
    preFixup = ''
      gappsWrapperArgs+=(--set LD_PRELOAD ${pkgs.gtk-layer-shell}/lib/libgtk-layer-shell.so)
    '';
  };

  screen-dim = pkgs.writeShellApplication {
    name = "screen-dim";
    runtimeInputs = with pkgs; [
      gawk
      libnotify
    ];
    text = ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/screen-dim.level"
      id_file="''${XDG_RUNTIME_DIR:-/tmp}/screen-dim.id"
      cur=$(cat "$state" 2>/dev/null || echo 1)

      case "''${1:-}" in
        down) new=$(awk -v c="$cur" 'BEGIN { v = c * 0.75; print (v < 0.05 ? 0.05 : v) }') ;;
        up) new=$(awk -v c="$cur" 'BEGIN { v = c / 0.75; print (v > 0.98 ? 1 : v) }') ;;
        reset) new=1 ;;
        *)
          echo "usage: screen-dim down|up|reset" >&2
          exit 2
          ;;
      esac

      echo "$new" > "$state"
      pid=$(cat "''${XDG_RUNTIME_DIR:-/tmp}/screen-dim.pid" 2>/dev/null || true)
      [ -n "$pid" ] && kill -USR1 "$pid" 2>/dev/null || true

      pct=$(awk -v b="$new" 'BEGIN { printf "%d%%", b * 100 + 0.5 }')
      old=$(cat "$id_file" 2>/dev/null || echo 0)
      notify-send -p -r "$old" -t 1200 "Screen" "$pct" > "$id_file"
    '';
  };
in
{
  environment.systemPackages = [
    overlay
    screen-dim
  ];

  environment.etc."sway/config.d/screen-dim.conf".text = ''
    exec ${overlay}/bin/screen-dim-overlay
    bindsym $mod+minus exec screen-dim down
    bindsym $mod+equal exec screen-dim up
    bindsym $mod+0 exec screen-dim reset
  '';
}
