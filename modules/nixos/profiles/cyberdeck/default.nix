# Cyberdeck look for the PocketTerm35: one palette (./palette.nix) drives the
# wallpaper, Sway chrome, Waybar, foot, rofi, mako, GTK apps, the cursor, the
# Linux console and the tuigreet greeter. Session wiring (keybinds, autostart,
# greetd autologin) lives in ../wayland-kiosk.nix; this module is only the look.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  p = import ./palette.nix;
  user = "jdreier";
  font = "JetBrainsMono Nerd Font";

  plymouthTheme = import ./plymouth.nix {
    inherit pkgs;
    palette = p;
  };

  wallpaper = import ./wallpaper.nix {
    inherit pkgs;
    palette = p;
  };

  # Nerd Font glyph from its codepoint. Built from a JSON escape so the Private
  # Use Area characters can't be silently stripped from the source (which is
  # how the old bar lost every icon). Codepoints above U+FFFF take a surrogate
  # pair, e.g. (icon "udb80\\udf5b") for nf-md-memory.
  icon = code: builtins.fromJSON ''"\${code}"'';
  i = {
    nixos = icon "uf313";
    wifi = icon "uf1eb";
    ethernet = icon "uf0e8";
    offline = icon "uf127";
    volOff = icon "uf026";
    volLow = icon "uf027";
    volHigh = icon "uf028";
    cpu = icon "uf2db";
    memory = icon "udb80\\udf5b";
    temp = icon "uf2c9";
    power = icon "uf011";
    game = icon "uf11b";
    bluetooth = icon "uf293";
    lock = icon "uf023";
    logout = icon "uf08b";
    reboot = icon "uf021";
  };

  swaylockConfig = ''
    image=${wallpaper}
    scaling=fill
    font=${font}
    # Always show the ring + clock even before a key is pressed: otherwise the
    # lock screen is indistinguishable from the desktop wallpaper and reads as
    # "no login" (nothing shows it's locked or where to type). NOTE: this
    # swaylock has no bare "indicator" option -- passing it aborts swaylock with
    # a parse error and the screen goes solid red, so use indicator-idle-visible.
    indicator-idle-visible
    clock
    indicator-radius=64
    indicator-thickness=6
    show-failed-attempts
    ignore-empty-password
    inside-color=${p.base}cc
    ring-color=${p.cyan}ff
    key-hl-color=${p.green}ff
    bs-hl-color=${p.magenta}ff
    text-color=${p.text}ff
    line-color=00000000
    separator-color=00000000
    inside-clear-color=${p.base}cc
    ring-clear-color=${p.amber}ff
    text-clear-color=${p.amber}ff
    inside-ver-color=${p.base}cc
    ring-ver-color=${p.blue}ff
    text-ver-color=${p.blue}ff
    inside-wrong-color=${p.base}cc
    ring-wrong-color=${p.red}ff
    text-wrong-color=${p.red}ff
    line-clear-color=00000000
    line-ver-color=00000000
    line-wrong-color=00000000
  '';

  cursor = {
    name = "Bibata-Modern-Classic";
    size = 20;
    package = pkgs.bibata-cursors;
  };
  gtkTheme = {
    name = "adw-gtk3-dark";
    package = pkgs.adw-gtk3;
  };
  iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme.override { color = "cyan"; };
  };

  # --- Waybar -----------------------------------------------------------------
  # 24px tall, text-and-glyph modules (no pills: 640px is tight). Workspace
  # focus is a solid cyan block, everything else is colored text on near-black.
  waybarConfig = pkgs.writeText "waybar-config" (
    builtins.toJSON {
      layer = "top";
      position = "top";
      height = 24;
      spacing = 0;
      modules-left = [
        "custom/logo"
        "sway/workspaces"
        "sway/mode"
        "custom/game"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "network"
        "bluetooth"
        "pulseaudio"
        "cpu"
        "memory"
        "temperature"
        "custom/power"
      ];
      "custom/game" = {
        format = i.game;
        tooltip = false;
        on-click = "retroarch";
      };
      "custom/power" = {
        format = i.power;
        tooltip = false;
        on-click = "powermenu";
      };
      "custom/logo" = {
        format = i.nixos;
        tooltip = false;
      };
      "sway/workspaces".disable-scroll = true;
      "sway/mode".format = "[{}]";
      clock = {
        format = "{:%H:%M  %a %d}";
        tooltip = false;
      };
      network = {
        format-wifi = "${i.wifi} {signalStrength}";
        format-ethernet = "${i.ethernet} {ipaddr}";
        format-disconnected = "${i.offline} off";
        tooltip-format = "{ifname}: {ipaddr}";
        on-click = "netmenu";
      };
      bluetooth = {
        format = i.bluetooth;
        format-connected = "${i.bluetooth} {num_connections}";
        format-off = i.bluetooth;
        format-disabled = i.bluetooth;
        tooltip = false;
        on-click = "btmenu";
      };
      pulseaudio = {
        format = "{icon} {volume}";
        format-muted = "${i.volOff} --";
        format-icons.default = [
          i.volOff
          i.volLow
          i.volHigh
        ];
        on-click = "volmenu";
        on-click-right = "pavucontrol";
      };
      cpu = {
        format = "${i.cpu} {usage}";
        interval = 3;
      };
      memory = {
        format = "${i.memory} {percentage}";
        interval = 5;
      };
      temperature = {
        thermal-zone = 0;
        format = "${i.temp} {temperatureC}°";
        critical-threshold = 85; # the Pi 5 idles around 75-80°C in this case
      };
    }
  );

  waybarStyle = pkgs.writeText "waybar-style.css" ''
    * {
      font-family: "${font}", monospace;
      font-size: 11px;
      min-height: 0;
      border: none;
      border-radius: 0;
    }
    window#waybar {
      background: alpha(#${p.void}, 0.92);
      color: #${p.text};
      border-bottom: 1px solid alpha(#${p.cyan}, 0.35);
    }
    #custom-logo { color: #${p.cyan}; padding: 0 8px 0 9px; font-size: 13px; }
    #workspaces button {
      padding: 0 7px;
      color: #${p.overlay};
      background: transparent;
    }
    #workspaces button.focused { background: #${p.cyan}; color: #${p.void}; font-weight: bold; }
    #workspaces button.urgent { background: #${p.magenta}; color: #${p.void}; }
    #workspaces button:hover { background: #${p.surface}; box-shadow: none; }
    #mode { color: #${p.magenta}; padding: 0 6px; font-weight: bold; }
    #clock { color: #${p.amber}; font-weight: bold; letter-spacing: 1px; }
    #network, #bluetooth, #pulseaudio, #cpu, #memory, #temperature { padding: 0 6px; }
    #bluetooth { color: #${p.blue}; }
    #bluetooth.connected { color: #${p.cyan}; }
    #bluetooth.off, #bluetooth.disabled { color: #${p.overlay}; }
    #network { color: #${p.cyan}; }
    #network.disconnected { color: #${p.overlay}; }
    #pulseaudio { color: #${p.magenta}; }
    #pulseaudio.muted { color: #${p.overlay}; }
    #cpu { color: #${p.green}; }
    #memory { color: #${p.purple}; }
    #temperature { color: #${p.amber}; }
    #custom-game { color: #${p.green}; padding: 0 8px; font-size: 13px; }
    #custom-power { color: #${p.red}; padding: 0 10px 0 8px; font-size: 13px; }
    #temperature.critical { color: #${p.void}; background: #${p.red}; }
  '';

  # --- foot -------------------------------------------------------------------
  # Slightly translucent so the wallpaper glows through the terminal, which is
  # what's on screen most of the time. Same palette in the dark and light
  # sections so the compositor's light/dark preference can't flip it.
  footColors = ''
    alpha=0.9
    background=${p.base}
    foreground=${p.text}
    ${lib.concatImapStringsSep "\n" (
      n: c: if n <= 8 then "regular${toString (n - 1)}=${c}" else "bright${toString (n - 9)}=${c}"
    ) p.ansi}
    cursor=${p.void} ${p.green}
    selection-foreground=${p.void}
    selection-background=${p.cyan}
    urls=${p.magenta}
  '';
  footConfig = pkgs.writeText "foot.ini" ''
    font=${font}:size=11
    pad=4x2
    dpi-aware=no

    [cursor]
    style=block
    blink=yes

    [mouse]
    hide-when-typing=yes

    [colors-dark]
    ${footColors}
    [colors-light]
    ${footColors}
  '';

  # --- mako -------------------------------------------------------------------
  makoConfig = pkgs.writeText "mako-config" ''
    font=${font} 10
    background-color=#${p.base}f2
    text-color=#${p.text}
    border-color=#${p.cyan}
    border-size=2
    border-radius=0
    padding=8,10
    margin=8
    width=300
    height=140
    icons=1
    max-icon-size=32
    default-timeout=5000
    format=<b><span foreground="#${p.cyan}">%s</span></b>\n%b

    [urgency=low]
    border-color=#${p.overlay}

    [urgency=critical]
    border-color=#${p.magenta}
    format=<b><span foreground="#${p.magenta}">%s</span></b>\n%b
    default-timeout=0
  '';

  # --- Sway chrome ------------------------------------------------------------
  # No gaps and no edge borders: on a 640x480 panel every pixel is content. A
  # 1px line only appears *between* tiled windows, where it marks focus.
  swayTheme = pkgs.writeText "sway-theme.conf" ''
    output * bg ${wallpaper} fill
    font pango:${font} 9

    default_border pixel 1
    default_floating_border pixel 1
    hide_edge_borders both
    gaps inner 0
    gaps outer 0

    #                       border         bg          text          indicator      child_border
    client.focused          #${p.cyan}     #${p.base}  #${p.text}    #${p.magenta}  #${p.cyan}
    client.focused_inactive #${p.surface}  #${p.base}  #${p.subtext} #${p.surface}  #${p.surface}
    client.unfocused        #${p.mantle}   #${p.base}  #${p.overlay} #${p.mantle}   #${p.mantle}
    client.urgent           #${p.magenta}  #${p.base}  #${p.bright}  #${p.magenta}  #${p.magenta}

    seat * xcursor_theme ${cursor.name} ${toString cursor.size}
  '';

  # --- GTK --------------------------------------------------------------------
  # adw-gtk3 honours libadwaita's named colors, so recolor it to the palette.
  # GTK only reads gtk.css from the user's config dir (not /etc/xdg), hence the
  # tmpfiles symlinks below.
  gtkCss = pkgs.writeText "gtk.css" ''
    @define-color accent_color #${p.cyan};
    @define-color accent_bg_color #${p.cyan};
    @define-color accent_fg_color #${p.void};
    @define-color destructive_color #${p.red};
    @define-color destructive_bg_color #${p.red};
    @define-color success_color #${p.green};
    @define-color warning_color #${p.amber};
    @define-color error_color #${p.red};
    @define-color window_bg_color #${p.base};
    @define-color window_fg_color #${p.text};
    @define-color view_bg_color #${p.void};
    @define-color view_fg_color #${p.text};
    @define-color headerbar_bg_color #${p.mantle};
    @define-color headerbar_fg_color #${p.text};
    @define-color headerbar_backdrop_color #${p.base};
    @define-color sidebar_bg_color #${p.mantle};
    @define-color sidebar_fg_color #${p.text};
    @define-color card_bg_color #${p.mantle};
    @define-color card_fg_color #${p.text};
    @define-color popover_bg_color #${p.mantle};
    @define-color popover_fg_color #${p.text};
    @define-color dialog_bg_color #${p.mantle};
    @define-color dialog_fg_color #${p.text};
  '';
  gtkSettings = ''
    [Settings]
    gtk-theme-name=${gtkTheme.name}
    gtk-icon-theme-name=${iconTheme.name}
    gtk-cursor-theme-name=${cursor.name}
    gtk-cursor-theme-size=${toString cursor.size}
    gtk-font-name=Noto Sans 10
    gtk-application-prefer-dark-theme=1
  '';
in
{
  imports = [
    ./terminal.nix
    ./firefox.nix
    ./rofi.nix
  ];

  environment.etc = {
    "sway/config.d/theme.conf".source = swayTheme;
    "xdg/waybar/config".source = waybarConfig;
    "xdg/waybar/style.css".source = waybarStyle;
    "xdg/foot/foot.ini".source = footConfig;
    "xdg/mako/config".source = makoConfig;
    "xdg/gtk-3.0/settings.ini".text = gtkSettings;
    "xdg/gtk-4.0/settings.ini".text = gtkSettings;
    # swaylock only searches its own install prefix, never /etc, so every
    # caller passes -C /etc/swaylock/config (powermenu, swayidle).
    "swaylock/config".text = swaylockConfig;
  };

  systemd.tmpfiles.rules = [
    "d /home/${user}/.config 0755 ${user} users -"
    "d /home/${user}/.config/gtk-3.0 0755 ${user} users -"
    "d /home/${user}/.config/gtk-4.0 0755 ${user} users -"
    "L+ /home/${user}/.config/gtk-3.0/gtk.css - - - - ${gtkCss}"
    "L+ /home/${user}/.config/gtk-4.0/gtk.css - - - - ${gtkCss}"
  ];

  # GTK on Wayland reads its theme from GSettings, not settings.ini.
  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        settings."org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          gtk-theme = gtkTheme.name;
          icon-theme = iconTheme.name;
          cursor-theme = cursor.name;
          cursor-size = lib.gvariant.mkInt32 cursor.size;
          font-name = "Noto Sans 10";
          monospace-font-name = "${font} 10";
        };
      }
    ];
  };

  environment.variables = {
    XCURSOR_THEME = cursor.name;
    XCURSOR_SIZE = toString cursor.size;
  };

  environment.systemPackages = [
    cursor.package
    gtkTheme.package
    iconTheme.package
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
  ];

  # Console + greeter. The VT palette is what tuigreet's named colors resolve
  # to, so the greeter picks up the neon accents for free. A bigger console
  # font (Terminus 10x20) makes the tiny 640x480 panel legible at the greeter
  # and any TTY -- the kernel 8x16 default is uncomfortably small here. 20px
  # still leaves 24 rows x 64 cols.
  console.colors = p.ansi;
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v20n.psf.gz";
  console.packages = [ pkgs.terminus_font ];
  services.greetd.settings.default_session.command = lib.concatStringsSep " " [
    "${pkgs.tuigreet}/bin/tuigreet"
    "--time"
    "--asterisks"
    "--remember"
    "--greeting 'POCKETTERM // AUTHORIZED ACCESS ONLY'"
    "--theme 'border=cyan;title=cyan;greet=magenta;text=white;prompt=green;time=yellow;action=cyan;button=magenta;input=white;container=black'"
    "--cmd sway"
  ];

  # Single-line neon prompt for every interactive bash.
  programs.bash.promptInit = builtins.readFile ./prompt.bash;

  # Boot splash on vc4 (loaded in the initrd below, up at ~1.5s).
  boot.plymouth = {
    enable = true;
    theme = plymouthTheme.themeName;
    themePackages = [ plymouthTheme ];
  };
  # Plymouth quits ~3s before Sway takes the panel, which flashed the text
  # console in between. --retain-splash leaves the last splash frame on
  # screen until Sway draws over it.
  systemd.services.plymouth-quit.serviceConfig.ExecStart = [
    ""
    "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
  ];

  # Quiet boot: the vendor default (loglevel=7) floods the panel with kernel
  # debug output. Errors still reach the console.
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    # No [ OK ] status lines on the panel; the splash covers boot instead.
    "systemd.show_status=false"
    "rd.systemd.show_status=false"
    "vt.global_cursor_default=0"
    # The vendor cmdline has console=serial0; with any serial console present
    # Plymouth forces its text-only "details" splash and never draws the theme.
    # This keeps the serial console but lets the graphical splash run.
    "plymouth.ignore-serial-consoles"
  ];

  # The panel shows nothing from the firmware framebuffer (simpledrm) once the
  # kernel is up, and vc4 only came up from the root fs at ~6.5s -- so Plymouth
  # ran on a dark screen and the first thing visible was console text. vc4's
  # HDMI binding also waits on the HDMI DDC I2C controllers (brcmstb-i2c), so
  # both go in the initrd to give Plymouth the real KMS device from ~2s.
  boot.initrd.kernelModules = [
    "i2c-brcmstb"
    "vc4"
  ];
}
