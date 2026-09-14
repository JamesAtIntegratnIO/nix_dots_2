{ pkgs, ... }:

{
  imports = [
    ./ai.nix
    ./cinnamon.nix
    ./development.nix
    ./git.nix
    ./shell.nix
  ];

  home = {
    username = "boboysdadda";
    homeDirectory = "/home/boboysdadda";
    stateVersion = "26.05";

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    packages = with pkgs; [
      bat
      bottom
      curl
      fd
      file
      inxi
      jq
      ripgrep
      tree
      unzip
      wget
      zip
    ];
  };

  programs.home-manager.enable = true;
  xdg.enable = true;
}
