# Cyberdeck palette for the PocketTerm35: near-black blue-greys with neon
# accents. Plain hex strings without "#", so each consumer can add its own
# prefix/alpha suffix (foot wants "rrggbb", fuzzel "rrggbbaa", CSS "#rrggbb").
rec {
  # Surfaces, darkest to lightest.
  void = "05070a"; # wallpaper edges, deepest shadow
  base = "0b0f14"; # terminal / panel background
  mantle = "121a22"; # raised surfaces (bar modules, menus)
  surface = "1c2833"; # borders of unfocused things, ANSI black
  overlay = "3b5160"; # dim text, inactive icons, ANSI bright black
  subtext = "7f93a3"; # secondary text
  text = "d4e2ea"; # primary text
  bright = "eef6fa";

  # Accents.
  cyan = "00e5ff"; # primary accent: focus, borders, prompt
  green = "39ff9f"; # ok / matches / cursor
  magenta = "ff2e88"; # secondary accent: urgent, highlights
  amber = "ffb000"; # warnings, clock
  red = "ff3355"; # errors, critical
  blue = "3d8bff";
  purple = "a970ff";

  # Brighter variants for the ANSI "bright" slots.
  cyanBright = "6ef2ff";
  greenBright = "7dffc0";
  magentaBright = "ff6fb0";
  amberBright = "ffcc4d";
  redBright = "ff6b85";
  blueBright = "7ab0ff";

  # The 16 ANSI colors, in order (0-7 regular, 8-15 bright). Shared by foot
  # and the Linux console so the TTY, greeter and terminal all match.
  ansi = [
    surface
    red
    green
    amber
    blue
    magenta
    cyan
    "b8c7d1"
    overlay
    redBright
    greenBright
    amberBright
    blueBright
    magentaBright
    cyanBright
    bright
  ];
}
