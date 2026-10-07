# The cyberdeck look on the Mac, user half: the same palette and wallpaper as
# modules/nixos/profiles/cyberdeck, on the parts of macOS that can take them.
# The font and system defaults are in ../../cyberdeck.nix.
#
# This file is the part only macOS has: the wallpaper, the screen saver and
# Terminal.app's profile. Terminal maps the 16 ANSI slots to the palette, and
# the shared tools in ../../../home/cyberdeck.nix draw with those slots, so a
# session opened from the laptop's terminal looks the same as one opened here.
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
lib.mkMerge [
  # The prompt, CLI tools, file-listing colors and editor themes, shared with
  # the laptop.
  (import ../../../home/cyberdeck.nix { inherit pkgs lib; })
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
    };
    programs.fzf.enableZshIntegration = true;
    programs.starship.enableZshIntegration = true;
  }
]
