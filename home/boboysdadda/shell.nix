{ pkgs, ... }:

{
  programs = {
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
    };

    tmux = {
      enable = true;
      baseIndex = 1;
      escapeTime = 0;
      keyMode = "vi";
      mouse = true;
      prefix = "C-Space";

      plugins = with pkgs.tmuxPlugins; [
        sensible
        vim-tmux-navigator
        resurrect
      ];

      extraConfig = ''
        bind N new-window
        bind y setw synchronize-panes
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R
        set -g renumber-windows on
      '';
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      history = {
        size = 50000;
        save = 10000;
        expireDuplicatesFirst = true;
        extended = true;
        ignorePatterns = [
          "rm *"
          "pkill *"
        ];
      };

      dirHashes = {
        docs = "$HOME/Documents";
        downloads = "$HOME/Downloads";
        projects = "$HOME/projects";
        dots = "$HOME/projects/nix_dots";
      };

      shellAliases = {
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
        grep = "grep --color=auto";
        psmem = "ps auxf | sort -nr -k 4";
        psmem10 = "ps auxf | sort -nr -k 4 | head -10";
        untar = "tar -zxvf";
        wget = "wget -c";
      };

      initContent = ''
        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
        zstyle ':completion:*' menu select
      '';
    };
  };
}
