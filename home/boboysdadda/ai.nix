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
}
