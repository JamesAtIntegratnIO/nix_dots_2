# Minimal Wayland desktop sized for the PocketTerm35's 640x480 panel: greetd
# autologins jdreier into Sway with a Waybar status bar, foot terminal, and
# fuzzel launcher, themed by ./cyberdeck. Deliberately lean -- no full DE.
{
  lib,
  pkgs,
  ...
}:

let
  user = "jdreier";

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

    # Desktop services
    exec waybar
    # mako only looks in ~/.config, so point it at the system config.
    exec mako --config /etc/xdg/mako/config
    # Mirror the primary selection into the clipboard, so tap-drag to highlight
    # (in foot or anywhere) is immediately pasteable with Ctrl+V everywhere.
    exec wl-paste --primary --watch wl-copy

    bindsym $mod+Return exec $term
    bindsym $mod+q kill
    bindsym $mod+d exec fuzzel
    bindsym $mod+e exec firefox
    bindsym $mod+f exec pcmanfm
    # Power menu (lock / log out / reboot / power off, with confirmation).
    # The Pi's power button opens it too; logind is told to ignore that key.
    bindsym $mod+Shift+e exec powermenu
    bindsym $mod+Escape exec powermenu
    bindsym XF86PowerOff exec powermenu

    # Screenshots: whole screen to clipboard, or region (drag with touch/trackpad).
    bindsym $mod+s exec grim - | wl-copy
    bindsym $mod+Shift+s exec grim -g "$(slurp)" - | wl-copy

    # Function-row hardware keys.
    bindsym XF86MonBrightnessUp   exec brightnessctl set +10%
    bindsym XF86MonBrightnessDown exec brightnessctl set 10%-
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

  environment.systemPackages = with pkgs; [
    # Session
    foot # terminal (touchscreen selection)
    fuzzel # app launcher
    waybar # status bar
    mako # notifications
    libnotify # notify-send
    swaybg # wallpaper

    # GUI apps that make sense on a 640x480 handheld
    firefox # browser (Pineapple web UI etc.)
    pcmanfm # file manager
    imv # image viewer
    mousepad # lightweight text editor
    pavucontrol # audio control

    # Terminal file manager (lighter than a GUI on this screen)
    yazi

    # Utilities
    brightnessctl
    git # also feeds the branch segment of the prompt
    wl-clipboard # wl-copy / wl-paste (clipboard + primary mirror)
    grim # screenshots
    slurp
  ];
}
