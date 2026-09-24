# Minimal Wayland session sized for the PocketTerm35's 640x480 panel: greetd
# autologins jdreier straight into Sway, with foot as the terminal. No display
# manager, no desktop environment.
{
  lib,
  pkgs,
  ...
}:

let
  user = "jdreier";

  # Sway config tuned for a tiny display: bigger font, no title bars or gaps so
  # every pixel counts, touch-friendly, and the built-in keyboard's brightness /
  # volume keys wired to the RP2040-backed function keys.
  swayConfig = pkgs.writeText "sway-config" ''
    set $mod Mod4
    set $term foot

    output * mode 640x480

    font pango:monospace 9
    default_border none
    gaps inner 0
    titlebar_padding 1

    input type:touch {
      map_to_output "*"
    }

    bindsym $mod+Return exec $term
    bindsym $mod+q kill
    bindsym $mod+d exec fuzzel
    bindsym $mod+e exec firefox
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
    foot # terminal
    fuzzel # launcher
    firefox # for the Pineapple web UI at http://172.16.52.1:1471
    brightnessctl
    wl-clipboard
    grim # screenshots
    slurp
  ];
}
