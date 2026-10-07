# Terminal apps in the cyberdeck look. Everything here draws with the 16 ANSI
# slots (bat's "ansi" theme, btop's "TTY" theme, fzf/tmux/ls color numbers), and
# foot maps those slots to ./palette.nix -- so the palette stays the single
# source of truth and nothing here hardcodes hex.
{ pkgs, ... }:

let
  # Shared with the Mac and the laptop (../../../home/cyberdeck.nix).
  cli = import ./cli.nix;

  # btop rewrites its config on exit, so it can't be a read-only store
  # symlink; tmpfiles seeds this copy once and leaves later edits alone.
  # Processes only: any layout with the cpu box needs 24 rows and foot at
  # 11pt gives 22. Press 1-4 in btop to toggle the other boxes.
  btopConf = pkgs.writeText "btop.conf" ''
    color_theme = "TTY"
    theme_background = False
    truecolor = False
    rounded_corners = False
    vim_keys = True
    update_ms = 1500
    proc_tree = True
    shown_boxes = "proc"
  '';
in
{
  environment.systemPackages = with pkgs; [
    btop
    bat
    delta
    eza
    neovim
    ripgrep
    fd
  ];

  systemd.tmpfiles.rules = [
    "d /home/jdreier/.config/btop 0755 jdreier users -"
    "C /home/jdreier/.config/btop/btop.conf - - - - ${btopConf}"
  ];

  environment.etc."bat/config".text = ''
    --theme=ansi
    --style=numbers,changes
  '';

  # fzf: Ctrl-R history, Ctrl-T files, Alt-C dirs; compact, no box.
  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };
  environment.variables.FZF_DEFAULT_OPTS = builtins.concatStringsSep " " cli.fzfOptions;

  # git: delta as pager, ANSI theme, no side-by-side (72 columns).
  programs.git = {
    enable = true;
    config = {
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        syntax-theme = "ansi";
        navigate = true;
        line-numbers = true;
      };
      merge.conflictStyle = "zdiff3";
    };
  };

  environment.variables.MANPAGER = cli.manpager;
  environment.variables.MANROFFOPT = "-P -c";

  # File listings in the palette, for ls and eza.
  environment.variables.LS_COLORS = cli.lsColors;
  environment.variables.EZA_COLORS = cli.ezaColors;
  environment.shellAliases.ll = "eza -la";

  # One prompt for every interactive shell, one line to save vertical space
  # on the 640x480 panel.
  programs.starship = {
    enable = true;
    settings = cli.starship;
  };

  # Neovim reads /etc/xdg/nvim as part of its runtime path: the scheme by
  # name, and the plugin file, sourced at startup, selects it.
  environment.etc."xdg/nvim/colors/cyberdeck.lua".text = import ./nvim.nix (import ./palette.nix);
  environment.etc."xdg/nvim/plugin/cyberdeck.lua".text = ''
    vim.cmd.colorscheme("cyberdeck")
  '';

  # tmux: one-line status bar at the bottom in the palette; mouse on so the
  # touchscreen can pick panes and scroll.
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    escapeTime = 10;
    terminal = "tmux-256color";
    extraConfig = ''
      set -g mouse on
    ''
    + cli.tmuxLook "";
  };
}
