# Terminal apps in the cyberdeck look. Everything here draws with the 16 ANSI
# slots (bat's "ansi" theme, btop's "TTY" theme, fzf/tmux color numbers), and
# foot maps those slots to ./palette.nix -- so the palette stays the single
# source of truth and nothing here hardcodes hex.
{ pkgs, ... }:

let
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
  environment.variables.FZF_DEFAULT_OPTS = builtins.concatStringsSep " " [
    "--height=60% --layout=reverse --info=inline-right --no-scrollbar"
    "--prompt='❯ ' --pointer='▌' --marker='+'"
    "--color=fg:7,bg:-1,hl:6,fg+:15,bg+:0,hl+:14"
    "--color=info:8,prompt:2,pointer:6,marker:5,spinner:5,header:4,border:8,gutter:-1"
  ];

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

  # man pages through less with color: bold -> cyan, underline -> magenta.
  environment.variables.MANPAGER = "less -R --use-color -Dd+c -Du+m";
  environment.variables.MANROFFOPT = "-P -c";

  # tmux: one-line status bar at the bottom in the palette; mouse on so the
  # touchscreen can pick panes and scroll.
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    escapeTime = 10;
    terminal = "tmux-256color";
    extraConfig = ''
      set -g mouse on
      set -g status-position bottom
      set -g status-style "bg=default,fg=colour8"
      set -g status-left "#[fg=colour0,bg=colour6,bold] #S #[default] "
      set -g status-left-length 20
      set -g status-right "#[fg=colour3]%H:%M"
      set -g window-status-format "#[fg=colour8] #I:#W "
      set -g window-status-current-format "#[fg=colour6,bold] #I:#W "
      set -g pane-border-style "fg=colour0"
      set -g pane-active-border-style "fg=colour6"
      set -g message-style "fg=colour2,bg=default"
      set -g mode-style "fg=colour0,bg=colour6"
    '';
  };
}
