# System half of the cyberdeck look on the Mac: the font, and the few pieces
# of macOS chrome that take a color or a string. The user half (wallpaper,
# Terminal profile, prompt, tmux, CLI tools) is ./home/cyberdeck.
#
# macOS has no theme engine, so this is as far as the system goes: the accent
# color is a fixed list with no cyan in it and stays at the default blue.
{
  pkgs,
  lib,
  hostname,
  ...
}:

let
  p = import ../nixos/profiles/cyberdeck/palette.nix;

  hexDigit = c: (builtins.fromTOML "x = 0x${c}").x;
  channels =
    hex:
    map (off: hexDigit (builtins.substring off 2 hex) / 255.0) [
      0
      2
      4
    ];

  # Selected text keeps its own color, and light text on full-strength cyan is
  # unreadable, so the highlight is the accent at under half brightness.
  highlight = map (c: c * 0.45) (channels p.cyan);
in
{
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  system.defaults = {
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    CustomUserPreferences.NSGlobalDomain.AppleHighlightColor = "${lib.concatMapStringsSep " " toString highlight} Other";
    # Shown on the lock and login screens, in the wallpaper's HUD wording.
    loginwindow.LoginwindowText = "${lib.toUpper hostname} // AUTHORIZED USE ONLY";
  };
}
