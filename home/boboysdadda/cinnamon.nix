{ ... }:

{
  xdg.dataFile."cinnamon/extensions/fullscreen-spaces@local" = {
    source = ./cinnamon/fullscreen-spaces;
    recursive = true;
  };
  # Its stylesheet.css comes from cyberdeck.nix, in the palette.
  xdg.dataFile."cinnamon/extensions/snap-layouts@local" = {
    source = ./cinnamon/snap-layouts;
    recursive = true;
  };

  dconf.settings = {
    "org/cinnamon".enabled-extensions = [
      "fullscreen-spaces@local"
      "snap-layouts@local"
    ];
    "org/cinnamon/desktop/wm/preferences".num-workspaces = 1;
    "org/cinnamon/muffin" = {
      workspace-cycle = true;
      # Drag to the left/right edge for halves, a corner for quarters, the top
      # to maximize (or onto snap-layouts' picker for other layouts).
      edge-tiling = true;
    };

    # Keep csd-power out of the lid switch; logind handles it (see
    # modules/nixos/profiles/laptop.nix). inhibit-lid-switch = false is the
    # documented way to hand lid handling to logind, and pinning both lid
    # actions to "nothing" makes sure a stray csd-power lid handler can't
    # re-suspend the machine a second after it resumes on lid open.
    "org/cinnamon/settings-daemon/plugins/power" = {
      inhibit-lid-switch = false;
      lid-close-ac-action = "nothing";
      lid-close-battery-action = "nothing";
      # Cinnamon's defaults never suspend an idle laptop and leave the panel
      # lit for half an hour. On battery: panel off at 5 minutes, suspend at
      # 15 (which locks, lock-on-suspend being the default). AC is left alone.
      sleep-display-battery = 300;
      sleep-inactive-battery-timeout = 900;
    };

    "org/cinnamon/desktop/keybindings/wm" = {
      switch-to-workspace-left = [
        "<Control>Left"
        "<Control><Alt>Left"
        "<Control><Super>Left"
      ];
      switch-to-workspace-right = [
        "<Control>Right"
        "<Control><Alt>Right"
        "<Control><Super>Right"
      ];
      switch-to-workspace-up = [
        "<Control><Alt>Up"
        "<Control><Super>Up"
      ];
      toggle-fullscreen = [ "<Super>f" ];
    };
  };
}
