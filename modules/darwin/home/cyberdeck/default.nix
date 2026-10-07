# The cyberdeck look on the Mac, user half: the same palette and wallpaper as
# modules/nixos/profiles/cyberdeck, on the parts of macOS that can take them.
# The font and system defaults are in ../../cyberdeck.nix.
#
# As on the PocketTerm, the terminal tools draw with the 16 ANSI slots and the
# terminal maps those to the palette, so nothing below hardcodes hex and a
# session opened from the laptop's (already themed) terminal looks the same as
# one opened in Terminal.app here.
{
  pkgs,
  lib,
  hostname,
}:

let
  p = import ../../../nixos/profiles/cyberdeck/palette.nix;
  monoFont = "JetBrainsMono Nerd Font";

  # Native renders for the 4K display, labelled with the hostname: one per
  # wallpaper style, shown in turn.
  wallpaperMinutes = 30;
  wallpapers = import ../../../nixos/profiles/cyberdeck/wallpapers.nix {
    inherit pkgs hostname;
    palette = p;
    name = "${hostname}-wallpaper";
    width = 3840;
    height = 2160;
    title = lib.toUpper hostname;
    os = "darwin";
    tags = [
      "aarch64"
      "m4max"
    ];
    footer = "3840×2160 · ARM64 · AQUA";
    node = "0x02";
    peers = [
      "pocketterm"
      "carbonite"
    ];
  };

  # The screen saver is the same renders in a .saver bundle, which
  # ./screensaver.js installs and selects.
  screensaver = pkgs.stdenv.mkDerivation {
    name = "Cyberdeck.saver";
    dontUnpack = true;
    infoPlist = pkgs.writeText "Info.plist" (
      lib.generators.toPlist { escape = true; } {
        CFBundleExecutable = "Cyberdeck";
        CFBundleIdentifier = "io.integratn.cyberdeck-saver";
        CFBundleName = "Cyberdeck";
        CFBundlePackageType = "BNDL";
        CFBundleShortVersionString = "1.0";
        CFBundleVersion = "1";
        NSPrincipalClass = "CyberdeckView";
      }
    );
    buildPhase = ''
      mkdir -p $out/Contents/MacOS
      $CC -fobjc-arc -bundle -O2 ${./screensaver.m} -o $out/Contents/MacOS/Cyberdeck \
        -framework ScreenSaver -framework QuartzCore -framework Cocoa
      cp $infoPlist $out/Contents/Info.plist
      cp -r ${wallpapers} $out/Contents/Resources
    '';
    dontInstall = true;
    dontFixup = true;
  };

  # Terminal.app keeps its profiles as archived NSColor/NSFont objects, so the
  # spec is plain JSON and ./terminal-profile.js does the archiving with AppKit.
  terminalProfile = pkgs.writeText "cyberdeck-terminal.json" (
    builtins.toJSON {
      name = "Cyberdeck";
      font = monoFont;
      fontSize = 13;
      opacity = 0.9; # foot's alpha on the deck
      background = p.base;
      text = p.text;
      bold = p.bright;
      cursor = p.green;
      # Terminal has no selection foreground, so cyan (foot's selection
      # background) would sit under light text. The dim grey stays readable.
      selection = p.overlay;
      inherit (p) ansi;
    }
  );
in
{
  home.activation.cyberdeckTerminal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/osascript -l JavaScript ${./terminal-profile.js} ${terminalProfile}
  '';

  home.activation.cyberdeckScreensaver = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/osascript -l JavaScript ${./screensaver.js} ${screensaver}
  '';

  # A launchd agent rather than an activation step: setting the wallpaper needs
  # the GUI session, which an SSH-driven rebuild may not have. It runs every
  # wallpaperMinutes and the script picks the style from the clock. The store
  # paths are in the arguments, so new renders reload the agent and apply
  # themselves.
  launchd.agents.cyberdeck-wallpaper = {
    enable = true;
    config = {
      ProgramArguments = [
        "/usr/bin/osascript"
        "-l"
        "JavaScript"
        "${./wallpaper.js}"
        (toString (wallpaperMinutes * 60))
      ]
      ++ map toString wallpapers.images;
      StartInterval = wallpaperMinutes * 60;
      RunAtLoad = true;
      ProcessType = "Background";
    };
  };

  programs.zsh = {
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = builtins.readFile ./prompt.zsh;
  };

  # fzf: Ctrl-R history, Ctrl-T files, Alt-C dirs; compact, no box.
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height=60% --layout=reverse --info=inline-right --no-scrollbar"
      "--prompt='❯ ' --pointer='▌' --marker='+'"
      "--color=fg:7,bg:-1,hl:6,fg+:15,bg+:0,hl+:14"
      "--color=info:8,prompt:2,pointer:6,marker:5,spinner:5,header:4,border:8,gutter:-1"
    ];
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

  # man pages through less with color: bold -> cyan, underline -> magenta.
  home.sessionVariables.MANPAGER = "less -R --use-color -Dd+c -Du+m";

  # One-line status bar in the palette, as on the deck.
  programs.tmux = {
    terminal = "tmux-256color";
    extraConfig = ''
      set -as terminal-features ",xterm-256color:RGB"
      set -g status-position bottom
      set -g status-style "bg=default,fg=colour8"
      set -g status-left "#[fg=colour0,bg=colour6,bold] #S #[default] "
      set -g status-left-length 20
      set -g status-right "#[fg=colour8]#h #[fg=colour3]%H:%M"
      set -g window-status-format "#[fg=colour8] #I:#W "
      set -g window-status-current-format "#[fg=colour6,bold] #I:#W "
      set -g pane-border-style "fg=colour0"
      set -g pane-active-border-style "fg=colour6"
      set -g message-style "fg=colour2,bg=default"
      set -g mode-style "fg=colour0,bg=colour6"
    '';
  };
}
