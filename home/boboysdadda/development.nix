{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Go
    go
    golangci-lint
    gopls

    # Kubernetes and platform engineering
    argocd
    kubectl
    kubectx
    kubernetes-helm
    kustomize
    stern

    # General development tooling
    gnumake
    just
    nil
    nixfmt-tree
    shellcheck
    shfmt
    vscode
    yaml-language-server
    yq-go
  ];

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withNodeJs = true;

      extraPackages = with pkgs; [
        fd
        gopls
        nil
        ripgrep
      ];

      initLua = ''
        vim.g.mapleader = ","
        vim.opt.number = true
        vim.opt.relativenumber = true
        vim.opt.expandtab = true
        vim.opt.shiftwidth = 2
        vim.opt.tabstop = 2
        vim.opt.termguicolors = true
      '';
    };
  };
}
