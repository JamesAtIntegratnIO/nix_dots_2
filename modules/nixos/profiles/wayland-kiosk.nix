# Minimal Wayland desktop sized for the PocketTerm35's 640x480 panel: greetd
# autologins jdreier into Sway with a Waybar status bar, foot terminal, and
# rofi launcher, themed by ./cyberdeck. Deliberately lean -- no full DE.
{
  lib,
  pkgs,
  ...
}:

let
  user = "jdreier";

  # Edge-swipe gestures on the touchscreen. lisgd reads the GT911 directly, so
  # apps still get their own touches; edge-only so in-app scrolling and
  # dragging are never hijacked. The panel and touch share 640x480 coords.
  # A wrapper so Sway (and a manual restart) run one line; extra args (e.g. -v
  # for debugging) pass through.
  edge-gestures = pkgs.writeShellScriptBin "edge-gestures" ''
    exec ${pkgs.lisgd}/bin/lisgd -d /dev/input/by-path/platform-1f00074000.i2c-event \
      -w 640 -h 480 -t 100 \
      -g '1,LR,L,*,R,ws-nav prev' \
      -g '1,RL,R,*,R,ws-nav next' \
      -g '1,UD,T,*,R,launcher' \
      -g '1,DU,B,*,R,powermenu' \
      "$@"
  '';

  # Turn the panel on/off. Powering vc4's HDMI output back on is flaky: a
  # `power on` sometimes reports success but leaves the output off, so "on"
  # retries until Sway reports it powered. (Wildcard `output *` looked worse
  # in testing, so the output is also named explicitly.)
  panel-power = pkgs.writeShellApplication {
    name = "panel-power";
    runtimeInputs = [ pkgs.sway ];
    text = ''
      out=HDMI-A-1
      case "''${1:-}" in
        off) swaymsg "output $out power off" >/dev/null ;;
        on)
          for _ in 1 2 3 4 5 6; do
            swaymsg "output $out power on" >/dev/null
            sleep 0.4
            swaymsg -t get_outputs | grep -q '"power": true' && exit 0
          done
          echo "panel-power: $out still off" >&2
          exit 1
          ;;
        *)
          echo "usage: panel-power on|off" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Sway config for the 640x480 display: touch mapped to the panel, Waybar/mako
  # started, hardware keys bound. The look (wallpaper, borders, gaps, colors,
  # cursor) comes from ./cyberdeck via /etc/sway/config.d, which also carries
  # NixOS's own nixos.conf (dbus/systemd environment import).
  swayConfig = pkgs.writeText "sway-config" ''
    set $mod Mod4
    set $term foot

    output * mode 640x480

    include /etc/sway/config.d/*

    input type:touch {
      map_to_output "*"
    }

    # Edge-swipe gestures (see edge-gestures above).
    exec edge-gestures

    # Desktop services
    exec waybar
    # mako only looks in ~/.config, so point it at the system config.
    exec mako --config /etc/xdg/mako/config
    # Mirror the primary selection into the clipboard, so tap-drag to highlight
    # (in foot or anywhere) is immediately pasteable with Ctrl+V everywhere.
    exec wl-paste --primary --watch wl-copy
    # Idle: blank the panel after 3 min (any key/touch wakes it), lock after
    # 10. Apps holding an idle inhibitor (RetroArch, video) keep it awake.
    # panel-power retries the wake, which vc4 sometimes drops.
    exec ${pkgs.swayidle}/bin/swayidle -w \
      timeout 180 'panel-power off' \
        resume 'panel-power on' \
      timeout 600 'swaylock -f -C /etc/swaylock/config' \
      before-sleep 'swaylock -f -C /etc/swaylock/config'
    # Games and videos in fullscreen never blank, even without an inhibitor.
    for_window [all] inhibit_idle fullscreen

    bindsym $mod+Return exec $term
    bindsym $mod+q kill
    bindsym $mod+d exec launcher
    bindsym $mod+e exec firefox
    bindsym $mod+f exec pcmanfm
    bindsym $mod+g exec retroarch

    # Power menu (lock / log out / reboot / power off, with confirmation).
    # The Pi's power button opens it too; logind is told to ignore that key.
    bindsym $mod+Shift+e exec powermenu
    bindsym $mod+Escape exec powermenu
    bindsym XF86PowerOff exec powermenu

    # Screenshots: whole screen to clipboard, or region (drag with touch/trackpad).
    bindsym $mod+s exec grim - | wl-copy
    bindsym $mod+Shift+s exec grim -g "$(slurp)" - | wl-copy

    # Function-row hardware keys. (Brightness has no binding: the keyboard's
    # RP2040 drives the backlight PWM itself on Fn+brightness.)
    bindsym XF86AudioRaiseVolume  exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    bindsym XF86AudioLowerVolume  exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindsym XF86AudioMute         exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

    # Workspaces mapped onto the number row.
    bindsym $mod+1 workspace number 1
    bindsym $mod+2 workspace number 2
    bindsym $mod+3 workspace number 3
    bindsym $mod+4 workspace number 4
    bindsym $mod+Shift+1 move container to workspace number 1
    bindsym $mod+Shift+2 move container to workspace number 2
    bindsym $mod+Shift+3 move container to workspace number 3
    bindsym $mod+Shift+4 move container to workspace number 4

    exec $term
  '';
in
{
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # greetd launches the plain `sway` binary, which reads /etc/sway/config -- so
  # put our config there. (programs.sway.extraOptions only affects the `sway`
  # wrapper, which greetd bypasses, so the upstream default config was winning.)
  environment.etc."sway/config".source = lib.mkForce swayConfig;

  # Touch-friendly file opening. pcmanfm opens on double-click by default, and
  # a finger's double-tap lands too far apart to count, so folders and files
  # never opened. libfm.conf is autogenerated and rewritten by pcmanfm on exit
  # (a system /etc/xdg copy is overridden by the user file), so set just this
  # key in the user's file on every activation; pcmanfm then keeps it.
  system.activationScripts.libfm-single-click = {
    deps = [ "users" ];
    text = ''
      f=/home/${user}/.config/libfm/libfm.conf
      if [ -f "$f" ]; then
        if grep -q '^single_click=' "$f"; then
          ${pkgs.gnused}/bin/sed -i 's/^single_click=.*/single_click=1/' "$f"
        else
          ${pkgs.gnused}/bin/sed -i '/^\[config\]/a single_click=1' "$f"
        fi
      else
        install -d -o ${user} -g users -m 700 "$(dirname "$f")"
        printf '[config]\nsingle_click=1\n' > "$f"
        chown ${user}:users "$f"
      fi
    '';
  };

  # What a tapped file opens in.
  xdg.mime.defaultApplications =
    let
      assoc =
        app: types:
        builtins.listToAttrs (
          map (t: {
            name = t;
            value = app;
          }) types
        );
    in
    assoc "pcmanfm.desktop" [ "inode/directory" ]
    // assoc "org.xfce.mousepad.desktop" [
      "text/plain"
      "text/markdown"
      "text/x-shellscript"
      "application/json"
      "application/x-yaml"
      "application/toml"
    ]
    // assoc "imv-dir.desktop" [
      "image/png"
      "image/jpeg"
      "image/gif"
      "image/webp"
      "image/bmp"
      "image/svg+xml"
    ]
    // assoc "firefox.desktop" [
      # So xdg-open (and thus a ctrl+clicked link in foot, or the `pager`
      # helper) opens web links in Firefox -- e.g. the Pager UI on :1471.
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ]
    // assoc "org.pwmt.zathura-pdf-mupdf.desktop" [ "application/pdf" ]
    // assoc "mpv.desktop" [
      "video/mp4"
      "video/webm"
      "video/x-matroska"
      "video/quicktime"
      "video/x-msvideo"
      "audio/mpeg"
      "audio/flac"
      "audio/ogg"
      "audio/x-wav"
      "audio/wav"
      "audio/mp4"
    ];

  # A short press of the Pi 5 power button opens the Sway power menu instead of
  # powering straight off. Holding it still forces a hard power-off in firmware.
  services.logind.settings.Login.HandlePowerKey = "ignore";

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${pkgs.sway}/bin/sway";
        inherit user;
      };
      # tuigreet command (themed) is set in ./cyberdeck.
      default_session.user = "greeter";
    };
  };

  # Secret Service for apps that keep keys in it (Fractal's Matrix session).
  services.gnome.gnome-keyring.enable = true;

  # Unlock the gnome-keyring login keyring on a password login through the
  # greeter. The autologin session has no password to unlock it with, so
  # there the keyring asks once per boot on first use (or never, if its
  # password is left empty).
  security.pam.services.greetd.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs; [
    # Session
    foot # terminal (touchscreen selection)
    waybar # status bar
    mako # notifications
    libnotify # notify-send
    panel-power
    edge-gestures
    swaybg # wallpaper

    # GUI apps that make sense on a 640x480 handheld
    pcmanfm # file manager
    imv # image viewer
    mpv # video / audio
    zathura # PDF viewer
    mousepad # lightweight text editor
    pavucontrol # audio control
    fractal # Matrix client; adaptive GTK4 layout, unlike Element

    # Terminal file manager (lighter than a GUI on this screen)
    yazi

    # Utilities
    git # also feeds the branch segment of the prompt
    wl-clipboard # wl-copy / wl-paste (clipboard + primary mirror)
    grim # screenshots
    slurp
  ];
}
