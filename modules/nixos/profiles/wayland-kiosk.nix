# Minimal Wayland desktop sized for the PocketTerm35's 640x480 panel: greetd
# autologins jdreier into Sway with a Waybar status bar, foot terminal, and
# fuzzel launcher, themed with Catppuccin Mocha. Deliberately lean -- no full DE.
{
  lib,
  pkgs,
  ...
}:

let
  user = "jdreier";

  # Subtle vertical-gradient wallpaper (Catppuccin base tones).
  wallpaper = pkgs.runCommand "pocketterm-wall.png" {
    nativeBuildInputs = [ pkgs.imagemagick ];
  } "magick -size 640x480 gradient:'#181825'-'#1e1e2e' $out";

  # Waybar tuned for the tiny screen: short height, compact modules. No battery
  # module (the UPS is not exposed to Linux) and no backlight (firmware-side).
  waybarConfig = pkgs.writeText "waybar-config" (
    builtins.toJSON {
      layer = "top";
      position = "top";
      height = 24;
      spacing = 4;
      modules-left = [ "sway/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [
        "pulseaudio"
        "network"
        "cpu"
        "temperature"
      ];
      "sway/workspaces".disable-scroll = true;
      clock = {
        format = "{:%H:%M  %a %d}";
        tooltip = false;
      };
      cpu = {
        format = " {usage}%";
        interval = 3;
      };
      temperature = {
        thermal-zone = 0;
        format = " {temperatureC}°C";
        critical-threshold = 80;
      };
      network = {
        format-wifi = "  {signalStrength}%";
        format-ethernet = "  {ipaddr}";
        format-disconnected = "  off";
        tooltip-format = "{ifname}: {ipaddr}";
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "  {volume}%";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = "pavucontrol";
      };
    }
  );

  waybarStyle = pkgs.writeText "waybar-style.css" ''
    * {
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 12px;
      min-height: 0;
    }
    window#waybar { background: #181825; color: #cdd6f4; }
    #workspaces button { padding: 0 6px; color: #a6adc8; background: transparent; }
    #workspaces button.focused { background: #313244; color: #89b4fa; }
    #clock { color: #f9e2af; }
    #cpu { color: #a6e3a1; }
    #temperature { color: #fab387; }
    #network { color: #89b4fa; }
    #pulseaudio { color: #f5c2e7; }
    #clock, #cpu, #temperature, #network, #pulseaudio { padding: 0 8px; }
    #temperature.critical { color: #f38ba8; }
  '';

  # Catppuccin Mocha palette, shared by foot's dark and light color sections so
  # the theme applies regardless of the compositor's light/dark preference.
  footPalette = ''
    background=1e1e2e
    foreground=cdd6f4
    regular0=45475a
    regular1=f38ba8
    regular2=a6e3a1
    regular3=f9e2af
    regular4=89b4fa
    regular5=f5c2e7
    regular6=94e2d5
    regular7=bac2de
    bright0=585b70
    bright1=f38ba8
    bright2=a6e3a1
    bright3=f9e2af
    bright4=89b4fa
    bright5=f5c2e7
    bright6=94e2d5
    bright7=a6adc8
    selection-foreground=1e1e2e
    selection-background=f5e0dc'';

  # foot: Catppuccin Mocha, readable font, small padding. foot supports
  # touchscreen selection, so tap-drag highlights text.
  footConfig = pkgs.writeText "foot.ini" ''
    font=JetBrainsMono Nerd Font:size=11
    pad=6x6
    dpi-aware=no

    [cursor]
    style=beam

    [mouse]
    hide-when-typing=yes

    [colors-dark]
    ${footPalette}
    [colors-light]
    ${footPalette}
  '';

  makoConfig = pkgs.writeText "mako-config" ''
    background-color=#1e1e2e
    text-color=#cdd6f4
    border-color=#89b4fa
    border-radius=6
    border-size=2
    font=JetBrainsMono Nerd Font 11
    default-timeout=5000
    width=320
  '';

  # Sway config for a 640x480 display: big-ish font, no title bars or gaps, touch
  # mapped to the panel, Waybar/mako/wallpaper started, hardware keys bound.
  swayConfig = pkgs.writeText "sway-config" ''
    set $mod Mod4
    set $term foot

    output * mode 640x480
    output * bg ${wallpaper} fill

    font pango:monospace 9
    default_border none
    gaps inner 0

    input type:touch {
      map_to_output "*"
    }

    # Desktop services
    exec waybar
    exec mako
    # Mirror the primary selection into the clipboard, so tap-drag to highlight
    # (in foot or anywhere) is immediately pasteable with Ctrl+V everywhere.
    exec wl-paste --primary --watch wl-copy

    bindsym $mod+Return exec $term
    bindsym $mod+q kill
    bindsym $mod+d exec fuzzel
    bindsym $mod+e exec firefox
    bindsym $mod+f exec pcmanfm
    bindsym $mod+Shift+e exit

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
  environment.etc."xdg/waybar/config".source = waybarConfig;
  environment.etc."xdg/waybar/style.css".source = waybarStyle;
  environment.etc."xdg/foot/foot.ini".source = footConfig;
  environment.etc."xdg/mako/config".source = makoConfig;

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${pkgs.sway}/bin/sway";
        inherit user;
      };
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd sway";
        user = "greeter";
      };
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
  ];

  environment.systemPackages = with pkgs; [
    # Session
    foot # terminal (touchscreen selection)
    fuzzel # app launcher
    waybar # status bar
    mako # notifications
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
    wl-clipboard # wl-copy / wl-paste (clipboard + primary mirror)
    grim # screenshots
    slurp
  ];
}
