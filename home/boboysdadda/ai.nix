{ inputs, pkgs, ... }:

let
  claudeDesktop = pkgs.callPackage "${inputs.claude-desktop}/nix/claude-desktop.nix" { };
  claudeDesktopFhs = pkgs.callPackage "${inputs.claude-desktop}/nix/fhs.nix" {
    claude-desktop = claudeDesktop;
  };
  codexDesktop = pkgs.callPackage ../../pkgs/codex-desktop.nix { };
in
{
  home.packages = with pkgs; [
    claudeDesktopFhs
    claude-code
    codexDesktop
    codex
  ];

  # Electron autodetects its secret store from XDG_CURRENT_DESKTOP and
  # doesn't know "Hyprland", so Claude Desktop finds no safeStorage and its
  # login doesn't survive a restart. Point it at gnome-keyring (unlocked by
  # PAM at login) through the launcher's config file, which applies however
  # the app is started. Same fix as Element in modules/nixos/profiles/element.nix.
  xdg.configFile."claude-desktop-debian/environment".text = ''
    CLAUDE_PASSWORD_STORE=gnome-libsecret
  '';
}
