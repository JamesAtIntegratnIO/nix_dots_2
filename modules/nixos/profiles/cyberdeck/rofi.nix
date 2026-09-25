# rofi (2.0, native Wayland) themed from the palette: the app launcher and
# every quick menu (../quickmenus) share /etc/rofi/config.rasi.
#
# Touch: rofi's Wayland backend has no wl_touch handling, but Sway falls back
# to simulating the pointer for surfaces that don't accept touch, so a tap is
# a left click. rofi's default needs a double click to accept a row, so the
# config makes a single click (= a single tap) accept.
{ pkgs, ... }:

let
  p = import ./palette.nix;
  font = "JetBrainsMono Nerd Font 12";

  theme = pkgs.writeText "cyberdeck.rasi" ''
    * {
      bg:        #${p.base}f2;
      raised:    #${p.mantle};
      line:      #${p.surface};
      fg:        #${p.text};
      dim:       #${p.subtext};
      faint:     #${p.overlay};
      accent:    #${p.cyan};
      ok:        #${p.green};
      hot:       #${p.magenta};
      font:      "${font}";
      background-color: transparent;
      text-color: @fg;
    }

    window {
      location: center;
      width: 78%;
      background-color: @bg;
      border: 2px;
      border-color: @accent;
      padding: 10px 12px;
    }

    mainbox { children: [ inputbar, message, listview ]; spacing: 8px; }

    inputbar { children: [ prompt, textbox-prompt-colon, entry ]; spacing: 0; }
    prompt { text-color: @ok; }
    textbox-prompt-colon { str: " ❯ "; expand: false; text-color: @ok; }
    entry { placeholder: ""; cursor-color: @accent; }

    message {
      border: 0 0 1px 0;
      border-color: @line;
      padding: 0 0 6px 0;
    }
    textbox { text-color: @dim; }

    listview {
      lines: 9;
      columns: 1;
      fixed-height: false;
      scrollbar: false;
      spacing: 2px;
    }

    element { padding: 5px 8px; spacing: 8px; }
    element-icon { size: 1.1em; }
    element-text { background-color: inherit; text-color: inherit; vertical-align: 0.5; }

    element normal.normal, element alternate.normal { text-color: @fg; }
    element normal.active, element alternate.active { text-color: @accent; }
    element normal.urgent, element alternate.urgent { text-color: @hot; }

    element selected.normal, element selected.active, element selected.urgent {
      background-color: #${p.cyan}26;
      border: 0 0 0 3px;
      border-color: @accent;
    }
    element selected.normal { text-color: #${p.bright}; }
    element selected.active { text-color: @accent; }
    element selected.urgent { text-color: @hot; }
  '';

  config = pkgs.writeText "rofi-config.rasi" ''
    configuration {
      show-icons: true;
      icon-theme: "Papirus-Dark";
      drun-display-format: "{name}";
      terminal: "foot";
      /* one tap (= Sway's simulated left click) selects and accepts */
      me-select-entry: "";
      me-accept-entry: "MousePrimary";
      hover-select: false;
    }
    @theme "${theme}"
  '';

  # App launcher (Super+D, swipe down from the top edge). A second call closes
  # it, like the quick menus.
  launcher = pkgs.writeShellApplication {
    name = "launcher";
    runtimeInputs = with pkgs; [
      rofi
      procps
    ];
    text = ''
      if pkill -x rofi; then exit 0; fi
      exec rofi -config /etc/rofi/config.rasi -show drun -display-drun apps
    '';
  };
in
{
  environment.etc."rofi/config.rasi".source = config;
  environment.systemPackages = [
    pkgs.rofi
    launcher
  ];
}
