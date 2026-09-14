{ ... }:

{
  xdg.dataFile."cinnamon/extensions/fullscreen-spaces@local" = {
    source = ./cinnamon/fullscreen-spaces;
    recursive = true;
  };

  dconf.settings = {
    "org/cinnamon".enabled-extensions = [ "fullscreen-spaces@local" ];
    "org/cinnamon/desktop/wm/preferences".num-workspaces = 1;
    "org/cinnamon/muffin".workspace-cycle = true;
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
