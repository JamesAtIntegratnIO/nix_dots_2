# The PocketTerm's cyberdeck look on the laptop's Cinnamon desktop: same
# palette, GTK recolor, icons, terminal colors and wallpaper as
# modules/nixos/profiles/cyberdeck, but none of its 640x480 sizing. UI font,
# cursor size, panel height and Cinnamon's spacing are left at laptop values.
#
# The theme, icons, wallpaper, greeter and boot splash are system-wide
# (modules/nixos/profiles/cyberdeck/cinnamon.nix); this file only points the
# session at them.
{ lib, osConfig, ... }:

let
  p = import ../../modules/nixos/profiles/cyberdeck/palette.nix;
  monoFont = "JetBrainsMono Nerd Font";
  themeName = "Cyberdeck"; # Cinnamon shell + GTK, one directory
  iconTheme = "Papirus-Dark";
  wallpaper = osConfig.services.xserver.displayManager.lightdm.background;
  # Every wallpaper style, as a directory. The store path rather than /etc, so
  # new renders change the setting and Cinnamon reloads them.
  wallpapers = osConfig.environment.etc."cyberdeck/wallpapers".source;
  host = osConfig.networking.hostName;

  # GTK3 apps get the palette from the theme itself; libadwaita (GTK4) apps
  # ignore the theme name and only read ~/.config/gtk-4.0/gtk.css.
  gtkCss = import ../../modules/nixos/profiles/cyberdeck/gtk-colors.nix p;

  hexDigit = c: (builtins.fromTOML "x = 0x${c}").x;
  rgba =
    hex: a:
    "rgba(${
      lib.concatMapStringsSep ", " (off: toString (hexDigit (builtins.substring off 2 hex))) [
        0
        2
        4
      ]
    }, ${a})";
in
{
  fonts.fontconfig.enable = true;

  # snap-layouts@local (home/boboysdadda/cinnamon.nix): the layout picker that
  # drops down when a window is dragged to the top edge, the same thumbnails
  # in the window menu, and the on-screen preview of the hovered zone.
  xdg.dataFile."cinnamon/extensions/snap-layouts@local/stylesheet.css".text = ''
    .snap-picker {
      spacing: 10px; padding: 10px;
      background-color: ${rgba p.void "0.94"};
      border: 1px solid ${rgba p.cyan "0.6"};
      box-shadow: 0 0 12px ${rgba p.cyan "0.35"}; }
    .snap-menu-item .snap-picker {
      padding: 4px 0; background-color: transparent; border: none; box-shadow: none; }
    .snap-layout { background-color: #${p.base}; border: 1px solid #${p.surface}; }
    .snap-cell { background-color: #${p.mantle}; border: 1px solid #${p.overlay}; }
    .snap-cell:hover, .snap-cell:focus {
      background-color: ${rgba p.cyan "0.45"}; border-color: #${p.cyan}; }
    .snap-preview {
      background-color: ${rgba p.cyan "0.12"};
      border: 2px solid ${rgba p.cyan "0.8"}; }
  '';

  # Leaves gtk.font and the cursor alone so the laptop keeps its own sizes.
  gtk = {
    enable = true;
    theme.name = themeName;
    iconTheme.name = iconTheme;
    gtk4.extraCss = gtkCss;
  };

  # Cinnamon reads its own keys rather than org/gnome/desktop/interface, and
  # its settings daemon pushes these to GTK apps over XSETTINGS.
  dconf.settings = {
    "org/cinnamon/theme".name = themeName;
    "org/cinnamon/desktop/interface" = {
      gtk-theme = themeName;
      icon-theme = iconTheme;
    };
    "org/cinnamon/desktop/wm/preferences".theme = themeName;
    "org/gnome/desktop/interface".monospace-font-name = "${monoFont} 10"; # same size as the DejaVu Sans Mono 10 it replaces
    "org/x/apps/portal".color-scheme = "prefer-dark";
    "org/cinnamon/desktop/background" = {
      picture-uri = "file://${wallpaper}";
      picture-options = "zoom";
    };
    # Cinnamon's own slideshow, in filename order; picture-uri above is what
    # shows until it first runs.
    "org/cinnamon/desktop/background/slideshow" = {
      slideshow-enabled = true;
      image-source = "directory://${wallpapers}";
      delay = 30; # minutes
      random-order = false;
    };

    # Lock screen: it draws over the desktop background, and its colors come
    # from the theme's .csstage rules. The fonts default to Ubuntu, which isn't
    # installed, and the away message gets the wallpaper's HUD wording.
    "org/cinnamon/desktop/screensaver" = {
      font-time = "${monoFont} Bold 64";
      font-date = "${monoFont} 20";
      font-message = "${monoFont} 13";
      default-message = "${lib.toUpper host} // AUTHORIZED USE ONLY";
    };
  };

  # gnome-terminal is Cinnamon's default terminal; give it foot's colors from
  # the deck (the palette's ANSI list is the same 16 slots). No font set, so it
  # follows the system monospace font above.
  programs.gnome-terminal = {
    enable = true;
    showMenubar = false;
    profile."b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
      default = true;
      visibleName = "Cyberdeck";
      cursorShape = "block";
      cursorBlinkMode = "on";
      transparencyPercent = 10;
      colors = {
        foregroundColor = "#${p.text}";
        backgroundColor = "#${p.base}";
        palette = map (c: "#${c}") p.ansi;
        cursor = {
          foreground = "#${p.void}";
          background = "#${p.green}";
        };
        highlight = {
          foreground = "#${p.void}";
          background = "#${p.cyan}";
        };
      };
    };
  };
}
