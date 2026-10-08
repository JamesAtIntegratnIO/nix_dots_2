# Hyprland as a second session next to Cinnamon. LightDM lists it because
# programs.hyprland registers its wayland-session file; Cinnamon is untouched
# and stays the default.
#
# It is here for one thing Cinnamon's window manager cannot do: every monitor
# has its own workspaces and switches them independently. The session itself
# (keys, bar, idle, lock) is the user's, in home/boboysdadda/hyprland.nix.
{
  imports = [
    # The launcher and its theme, shared with the PocketTerm.
    ./cyberdeck/rofi.nix
  ];

  programs.hyprland.enable = true;
  # Installs hyprlock and the PAM service it authenticates against.
  programs.hyprlock.enable = true;
}
