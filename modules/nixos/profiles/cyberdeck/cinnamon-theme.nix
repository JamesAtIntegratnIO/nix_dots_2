# Cinnamon shell theme (panel, menus, popups, OSDs, alt-tab) in the cyberdeck
# palette, for the laptop. It's Mint-Y-Dark-Aqua with every color remapped and
# nothing else touched, so all sizing and padding stay Mint's desktop-scale
# values rather than anything tuned for the PocketTerm's 640x480 panel.
#
# The remap works on the CSS and the SVG assets alike:
#   greys       -> the palette's surface ramp, by brightness (black stays black)
#   Mint aqua   -> cyan (lighter/darker shades keep their relative lightness)
#   reds        -> red; the window-list attention red -> magenta (urgent)
#   orange      -> amber
# A few color-only overrides appended at the end add the cyberdeck touches.
{
  pkgs,
  palette,
  name ? "Cyberdeck",
}:

let
  p = palette;
  src = "${pkgs.mint-themes}/share/themes/Mint-Y-Dark-Aqua/cinnamon";

  hexDigit = c: (builtins.fromTOML "x = 0x${c}").x;
  rgbOf = hex: map (off: toString (hexDigit (builtins.substring off 2 hex))) [ 0 2 4 ];
  rgba = hex: a: "rgba(${builtins.concatStringsSep ", " (rgbOf hex)}, ${a})";

  remap = pkgs.writeText "remap.py" ''
    import colorsys, re, sys

    def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    def mix(a, b, t): return tuple(round(x + (y - x) * t) for x, y in zip(a, b))

    # Grey brightness (0-255) -> palette color, interpolated between anchors.
    RAMP = [
        (0, (0, 0, 0)),
        (29, rgb("${p.void}")),
        (36, rgb("${p.base}")),
        (48, rgb("${p.mantle}")),
        (62, rgb("${p.surface}")),
        (95, rgb("${p.overlay}")),
        (165, rgb("${p.subtext}")),
        (225, rgb("${p.text}")),
        (255, rgb("${p.bright}")),
    ]
    CYAN, BASE, BRIGHT = rgb("${p.cyan}"), rgb("${p.base}"), rgb("${p.bright}")
    RED, MAGENTA, AMBER = rgb("${p.red}"), rgb("${p.magenta}"), rgb("${p.amber}")
    MINT_ACCENT_L = colorsys.rgb_to_hls(31 / 255, 158 / 255, 222 / 255)[1]

    # Hand-picked: the window-list hover tint becomes rofi's selection tint,
    # and "demands attention" becomes the urgent magenta, as on the deck.
    EXACT = {
        (0x3c, 0x56, 0x69): mix(BASE, CYAN, 0.18),
        (0xf0, 0x4a, 0x50): MAGENTA,
    }

    def grey(v):
        for (a, ca), (b, cb) in zip(RAMP, RAMP[1:]):
            if v <= b:
                return mix(ca, cb, (v - a) / (b - a))
        return RAMP[-1][1]

    def convert(c):
        if c in EXACT:
            return EXACT[c]
        h, l, s = colorsys.rgb_to_hls(*(x / 255 for x in c))
        if s < 0.18 or l < 0.06 or l > 0.97:
            return grey(sum(c) / 3)
        deg = h * 360
        if 180 <= deg <= 225:
            # Keep the shade's lightness relative to Mint's accent.
            return mix(BASE, CYAN, l / MINT_ACCENT_L) if l < MINT_ACCENT_L \
                else mix(CYAN, BRIGHT, (l - MINT_ACCENT_L) / (1 - MINT_ACCENT_L))
        if deg < 15 or deg > 345:
            return RED
        if deg < 45:
            return AMBER
        return c  # debug greens/blues and anything else: leave alone

    def hexsub(m):
        s = m.group(1)
        if len(s) == 3:
            s = "".join(ch * 2 for ch in s)
        return "#%02x%02x%02x" % convert(rgb(s))

    def rgbasub(m):
        r, g, b = convert(tuple(int(m.group(i)) for i in (2, 3, 4)))
        return "%s(%d, %d, %d%s)" % (m.group(1), r, g, b, m.group(5) or "")

    for path in sys.argv[1:]:
        text = open(path).read()
        text = re.sub(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b", hexsub, text)
        text = re.sub(r"(rgba?)\(\s*(\d+),\s*(\d+),\s*(\d+)(,\s*[\d.]+)?\s*\)", rgbasub, text)
        open(path, "w").write(text)
  '';

  # Color-only additions; no widths, paddings or borders change size.
  overrides = pkgs.writeText "cyberdeck-overrides.css" ''

    /* --- cyberdeck overrides ------------------------------------------- */

    /* Near-black panel with a faint neon edge, like the deck's Waybar. */
    .panel-top, .panel-bottom, .panel-left, .panel-right {
      background-color: ${rgba p.void "0.92"}; }
    .panel-top { box-shadow: 0 1px ${rgba p.cyan "0.35"}; }
    .panel-bottom { box-shadow: 0 -1px ${rgba p.cyan "0.35"}; }
    .panel-left { box-shadow: 1px 0 ${rgba p.cyan "0.35"}; }
    .panel-right { box-shadow: -1px 0 ${rgba p.cyan "0.35"}; }

    /* Menus and popups glow cyan instead of casting a grey shadow. */
    .menu { box-shadow: 0 0 8px ${rgba p.cyan "0.35"}; }

    /* Selected rows: rofi's tinted cyan with bright text. */
    .popup-menu-item:active,
    .menu-application-button-selected,
    .menu-category-button-selected {
      color: #${p.bright};
      background-color: ${rgba p.cyan "0.15"}; }

    /* Alt-tab gets the accent border the deck's rofi window has. */
    .switcher-list { border-color: #${p.cyan}; }
  '';
in
pkgs.runCommand "cinnamon-theme-${pkgs.lib.toLower name}" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  dir=$out/share/themes/${name}
  mkdir -p $dir
  cp -r ${src} $dir/cinnamon
  chmod -R u+w $dir
  python3 ${remap} $dir/cinnamon/cinnamon.css $(find $dir/cinnamon -name '*.svg')
  cat ${overrides} >> $dir/cinnamon/cinnamon.css
  cat > $dir/index.theme <<EOF
  [Desktop Entry]
  Type=X-GNOME-Metatheme
  Name=${name}
  Comment=Mint-Y-Dark recolored to the cyberdeck palette

  [X-GNOME-Metatheme]
  GtkTheme=adw-gtk3-dark
  IconTheme=Papirus-Dark
  CursorTheme=Bibata-Modern-Classic
  EOF
''
