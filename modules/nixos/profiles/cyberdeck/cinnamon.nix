# System half of the cyberdeck look on a Cinnamon laptop: everything that
# runs before (or outside) the user session -- boot splash, LightDM greeter,
# TTY colors -- plus the shared theme and wallpaper. The user half (dconf,
# gtk, gnome-terminal) is home/boboysdadda/cyberdeck.nix, which reads the
# wallpaper back from services.xserver.displayManager.lightdm.background so
# both sides show the same render.
#
# Unlike ./default.nix this sizes nothing for the PocketTerm's 640x480 panel.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  p = import ./palette.nix;
  host = config.networking.hostName;
  monoFont = "JetBrainsMono Nerd Font";

  theme = import ./cinnamon-theme.nix {
    inherit pkgs;
    palette = p;
  };
  iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme.override { color = "cyan"; };
  };

  # Native render for the X1 Carbon's 1920x1200 panel, labelled with the
  # hostname. The splash is the same picture with the status set to BOOTING.
  wallpaperArgs = {
    width = 1920;
    height = 1200;
    hostname = host;
    title = lib.toUpper host;
    tags = [
      "x86_64"
      "x1c9"
    ];
    footer = "1920×1200 · X86_64 · CINNAMON";
    node = "0x01";
  };
  wallpaper = import ./wallpaper.nix (
    {
      inherit pkgs;
      palette = p;
      name = "${host}-wallpaper";
    }
    // wallpaperArgs
  );
  plymouthTheme = import ./plymouth.nix {
    inherit pkgs;
    palette = p;
    wallpaperArgs = wallpaperArgs // {
      name = "${host}-splash";
    };
    description = "${host} cyberdeck boot splash";
  };
in
{
  environment.systemPackages = [
    theme
    iconTheme.package
  ];
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # --- LightDM ----------------------------------------------------------------
  # slick-greeter is what the Cinnamon module turns on. It runs as the lightdm
  # user, so it only sees system-wide themes and its own config.
  services.xserver.displayManager.lightdm = {
    background = wallpaper;
    greeters.slick = {
      theme = {
        name = "Cyberdeck";
        package = theme;
      };
      inherit iconTheme;
      font = {
        name = "${monoFont} 11";
        package = pkgs.nerd-fonts.jetbrains-mono;
      };
      # Show the cyberdeck wallpaper rather than whatever the user picked.
      draw-user-backgrounds = false;
      extraConfig = ''
        background-color=#${p.void}
        clock-format=%H:%M  %a %d
      '';
    };
  };

  # --- Boot splash ------------------------------------------------------------
  # i915 in the initrd gives Plymouth the real KMS device in time for the LUKS
  # passphrase prompt, which it draws over the splash. The initrd only carries
  # this one font, so it's the theme's JetBrains Mono rather than DejaVu.
  boot.plymouth = {
    enable = true;
    theme = plymouthTheme.themeName;
    themePackages = [ plymouthTheme ];
    font = "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf";
  };
  boot.initrd.kernelModules = [ "i915" ];
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "udev.log_level=3"
    "systemd.show_status=auto"
  ];

  # --- TTY --------------------------------------------------------------------
  console.colors = p.ansi;
}
