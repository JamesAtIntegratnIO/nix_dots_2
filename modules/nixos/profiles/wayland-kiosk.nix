# Minimal Wayland desktop sized for the PocketTerm35's 640x480 panel: greetd
# autologins jdreier into Sway with a Waybar status bar, foot terminal, and
# fuzzel launcher. Deliberately lean -- no full DE.
{
  lib,
  pkgs,
  ...
}:

let
  user = "jdreier";

  # Waybar tuned for the tiny screen: short height, compact modules. No battery
  # module (the UPS is not exposed to Linux) and no backlight (firmware-side).
  waybarConfig = pkgs.writeText "waybar-config" (
    builtins.toJSON {
      layer = "top";
      position = "top";
      height = 22;
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
    window#waybar { background: #1e1e2e; color: #cdd6f4; }
    #workspaces button { padding: 0 4px; color: #cdd6f4; background: transparent; }
    #workspaces button.focused { background: #45475a; }
    #clock, #cpu, #temperature, #network, #pulseaudio { padding: 0 6px; }
    #temperature.critical { color: #f38ba8; }
  '';

  # Sway config for a 640x480 display: big-ish font, no title bars or gaps, touch
  # mapped to the panel, Waybar/mako/wallpaper started, hardware keys bound.
  swayConfig = pkgs.writeText "sway-config" ''
    set $mod Mod4
    set $term foot

    output * mode 640x480
    output * bg #1e1e2e solid_color

    font pango:monospace 9
    default_border none
    gaps inner 0
    titlebar_padding 1

    input type:touch {
      map_to_output "*"
    }

    # Desktop services
    exec waybar
    exec mako

    bindsym $mod+Return exec $term
    bindsym $mod+q kill
    bindsym $mod+d exec fuzzel
    bindsym $mod+e exec firefox
    bindsym $mod+f exec pcmanfm
    bindsym $mod+Shift+e exit

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
    foot # terminal
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
    wl-clipboard
    grim # screenshots
    slurp
  ];
}
