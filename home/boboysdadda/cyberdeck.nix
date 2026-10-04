# The PocketTerm's cyberdeck look on the laptop's Cinnamon desktop: same
# palette, GTK recolor, icons, terminal colors and wallpaper as
# modules/nixos/profiles/cyberdeck, but none of its 640x480 sizing. UI font,
# cursor size, panel height and Cinnamon's spacing are left at laptop values.
{ pkgs, ... }:

let
  deck = ../../modules/nixos/profiles/cyberdeck;
  p = import (deck + "/palette.nix");
  monoFont = "JetBrainsMono Nerd Font";

  shellTheme = import (deck + "/cinnamon-theme.nix") {
    inherit pkgs;
    palette = p;
  };

  wallpaper = import (deck + "/wallpaper.nix") {
    inherit pkgs;
    palette = p;
    name = "nixos-wallpaper";
    hostname = "nixos";
    width = 1920;
    height = 1200;
    title = "NIXOS";
    tags = [
      "x86_64"
      "x1c9"
    ];
    footer = "1920×1200 · X86_64 · CINNAMON";
    node = "0x01";
  };

  gtkTheme = {
    name = "adw-gtk3-dark";
    package = pkgs.adw-gtk3;
  };
  iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme.override { color = "cyan"; };
  };

  # Same libadwaita named-color recolor as the PocketTerm (adw-gtk3 honours
  # these in GTK3; libadwaita apps read them from gtk-4.0/gtk.css).
  gtkCss = ''
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
in
{
  home.packages = [
    shellTheme
    pkgs.nerd-fonts.jetbrains-mono
  ];
  fonts.fontconfig.enable = true;

  # Leaves gtk.font and the cursor alone so the laptop keeps its own sizes.
  gtk = {
    enable = true;
    theme = gtkTheme;
    inherit iconTheme;
    gtk3.extraCss = gtkCss;
    gtk4.extraCss = gtkCss;
  };

  # Cinnamon reads its own keys rather than org/gnome/desktop/interface, and
  # its settings daemon pushes these to GTK apps over XSETTINGS.
  dconf.settings = {
    "org/cinnamon/theme".name = "Cyberdeck";
    "org/cinnamon/desktop/interface" = {
      gtk-theme = gtkTheme.name;
      icon-theme = iconTheme.name;
    };
    "org/cinnamon/desktop/wm/preferences".theme = gtkTheme.name;
    "org/gnome/desktop/interface".monospace-font-name = "${monoFont} 10"; # same size as the DejaVu Sans Mono 10 it replaces
    "org/x/apps/portal".color-scheme = "prefer-dark";
    "org/cinnamon/desktop/background" = {
      picture-uri = "file://${wallpaper}";
      picture-options = "zoom";
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
