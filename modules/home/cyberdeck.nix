# The cyberdeck look for the command line and the editors, for every host
# that has Home Manager (the Mac and the laptop): the prompt, the CLI tools,
# file-listing colors, and the Neovim and VS Code themes. The values come from
# ../nixos/profiles/cyberdeck, which the PocketTerm applies system-wide in its
# terminal.nix, so the three hosts cannot drift apart.
{ pkgs, lib, ... }:

let
  deck = ../nixos/profiles/cyberdeck;
  p = import (deck + "/palette.nix");
  cli = import (deck + "/cli.nix");
  vscodeTheme = import (deck + "/vscode-theme.nix") {
    inherit pkgs;
    palette = p;
  };

  inherit (pkgs.stdenv) isDarwin;
  vscodeUser = if isDarwin then "Library/Application Support/Code/User" else ".config/Code/User";

  # Selects the theme in VS Code's settings.json once, then never again, so a
  # later choice made in VS Code stays. The file is the user's and is JSON with
  # comments, so it is edited as text rather than parsed and rewritten.
  selectVscodeTheme = pkgs.writeShellScript "cyberdeck-vscode-select" ''
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gawk
      ]
    }
    settings="$HOME/${vscodeUser}/settings.json"
    marker="$HOME/.local/state/cyberdeck/vscode-theme-selected"
    key='"workbench.colorTheme"'
    value='"${vscodeTheme.label}"'

    [ -e "$marker" ] && exit 0
    [ -L "$settings" ] && exit 0 # managed by something else
    mkdir -p "$(dirname "$settings")" "$(dirname "$marker")"

    if [ ! -e "$settings" ] || ! grep -q '"' "$settings"; then
      printf '{\n  %s: %s\n}\n' "$key" "$value" > "$settings"
    else
      if grep -q "$key" "$settings"; then
        awk -v key="$key" -v value="$value" '
          !done && index($0, key) { sub(key "[ \t]*:[ \t]*\"[^\"]*\"", key ": " value); done = 1 }
          { print }' "$settings" > "$settings.cyberdeck"
      else
        awk -v key="$key" -v value="$value" '
          !done && /\{/ { sub(/\{/, "{\n  " key ": " value ","); done = 1 }
          { print }' "$settings" > "$settings.cyberdeck"
      fi
      cat "$settings.cyberdeck" > "$settings"
      rm "$settings.cyberdeck"
    fi
    touch "$marker"
  '';
in
{
  programs.starship = {
    enable = true;
    settings = cli.starship;
  };

  programs.fzf = {
    enable = true;
    defaultOptions = cli.fzfOptions;
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "ansi";
      style = "numbers,changes";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "ansi";
      navigate = true;
      line-numbers = true;
    };
  };
  programs.git.settings.merge.conflictStyle = "zdiff3";

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "TTY";
      theme_background = false;
      truecolor = false;
      rounded_corners = false;
      vim_keys = true;
    };
  };

  programs.tmux = {
    terminal = "tmux-256color";
    extraConfig = ''
      set -as terminal-features ",xterm-256color:RGB"
    ''
    + cli.tmuxLook "#[fg=colour8]#h ";
  };

  home.packages = [ pkgs.eza ];
  home.shellAliases.ll = "eza -la";
  home.sessionVariables = {
    MANPAGER = cli.manpager;
    LS_COLORS = cli.lsColors;
    EZA_COLORS = cli.ezaColors;
  };

  # Neovim finds both on its runtime path: the scheme by name, and the plugin
  # file, which it sources after init.lua, selects it. Nothing here touches
  # init.lua, so each host keeps its own.
  xdg.configFile."nvim/colors/cyberdeck.lua".text = import (deck + "/nvim.nix") p;
  xdg.configFile."nvim/plugin/cyberdeck.lua".text = ''
    vim.cmd.colorscheme("cyberdeck")
  '';

  # Where Home Manager installs VS Code it also links the theme in.
  programs.vscode.profiles.default.extensions = lib.mkIf (!isDarwin) [ vscodeTheme.extension ];

  home.activation.cyberdeckVscode = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    # The Mac's VS Code is installed by hand, so the theme goes in through its
    # own CLI, once per build of the theme.
    lib.optionalString isDarwin ''
      code="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
      stamp="$HOME/.local/state/cyberdeck/vscode-theme"
      if [ -x "$code" ] && [ "$(cat "$stamp" 2>/dev/null)" != "${vscodeTheme.vsix}" ]; then
        run mkdir -p "$(dirname "$stamp")"
        run "$code" --install-extension ${vscodeTheme.vsix} --force >/dev/null \
          && run eval 'echo ${vscodeTheme.vsix} > "$stamp"'
      fi
    ''
    + ''
      run ${selectVscodeTheme}
    ''
  );
}
