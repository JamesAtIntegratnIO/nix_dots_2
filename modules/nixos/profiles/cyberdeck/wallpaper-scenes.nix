# The wallpaper styles other than the horizon grid: what ./wallpaper.nix draws
# between the background and the wordmark. Each scene is
#   { body, defs, dy }
# where dy moves the wordmark up from its usual place to clear the scene.
#
# The scenes sit on the right of the canvas, measured from its right edge, so
# they stay clear of the wordmark at any aspect ratio. Nix has no trig, exp or
# random numbers, so those are built here: a Taylor series, repeated squaring
# and SHA-256 of a key. The renders are therefore the same on every build.
{
  lib,
  palette,
  font,
  vw,
  hostname,
  tags,
  peers,
  # The grid's horizon, which the skyline stands on.
  horizon,
  floorLines,
}:

let
  p = palette;
  s = toString;
  pi = 3.141592653589793;

  abs = x: if x < 0 then -x else x;
  # Fold the angle into [-pi/2, pi/2], where four terms are plenty.
  sin =
    x:
    let
      t = x - 2 * pi * builtins.floor (x / (2 * pi) + 0.5);
      u =
        if t > pi / 2 then
          pi - t
        else if t < -pi / 2 then
          -pi - t
        else
          t;
      u2 = u * u;
    in
    u * (1 - u2 / 6 * (1 - u2 / 20 * (1 - u2 / 42 * (1 - u2 / 72))));
  cos = x: sin (x + pi / 2);
  rad = d: d * pi / 180;
  # exp(-u^2) as (1 - u^2/1024)^1024.
  gauss =
    u:
    let
      b = 1 - u * u / 1024.0;
    in
    if b <= 0 then 0.0 else lib.foldl' (acc: _: acc * acc) b (lib.range 1 10);

  hex = h: (builtins.fromTOML "x = 0x${h}").x;
  hash = builtins.hashString "sha256";
  # The k-th number in [0, 1) from a hash (k = 0..9).
  rand = h: k: hex (builtins.substring (k * 6) 6 h) / 16777216.0;

  channels =
    h:
    map (o: hex (builtins.substring o 2 h)) [
      0
      2
      4
    ];
  mix =
    a: b: t:
    "rgb(${
      lib.concatStringsSep "," (
        lib.zipListsWith (x: y: s (builtins.floor (x + (y - x) * t + 0.5))) (channels a) (channels b)
      )
    })";

  # --- ridgeline: stacked terrain profiles, back (magenta) to front (cyan) ----
  ridgeline =
    let
      n = 30;
      cx = vw - 263;
      row =
        i:
        let
          t = i / (n - 1.0);
          y0 = 196 + t * 262;
          hr = hash "ridge:${s i}";
          ph = rand hr 0 * 2 * pi;
          ph2 = rand hr 1 * 2 * pi;
          point =
            j:
            let
              x = j * 6;
              hp = hash "ridge:${s i}:${s j}";
              env = gauss ((x - cx) / 170.0) + 0.3 * t * gauss ((x - 230) / 130.0);
              h =
                env * (abs (sin (x * 0.022 + ph)) * 34 + sin (x * 0.07 + ph2) * 9 + rand hp 0 * 7) * (0.5 + t * 0.9)
                + rand hp 1 * 1.2;
            in
            "L${s x} ${s (y0 - h)}";
        in
        # Filled, so each profile hides the ones behind it.
        ''<path d="M-5 ${s y0}${lib.concatStrings (lib.genList point (vw / 6 + 2))}L${s (vw + 5)} 486L-5 486Z" fill="#${p.base}" stroke="${mix p.magenta p.cyan t}" stroke-opacity="${s (0.25 + t * 0.6)}" stroke-width="1"/>'';
    in
    {
      dy = -88;
      defs = "";
      body = lib.concatStringsSep "\n" (lib.genList row n);
    };

  # --- traces: board traces fanning out of a chip named after the last tag ----
  traces =
    let
      cx = vw - 213;
      cy = 245;
      sz = 58;
      pin =
        side: i:
        let
          dx = builtins.elemAt side 0;
          dy = builtins.elemAt side 1;
          h = hash "trace:${s dx}:${s dy}:${s i}";
          off = -sz + 10 + i * ((2 * sz - 20) / 10.0);
          x = cx + dx * sz + (if dx != 0 then 0 else off);
          y = cy + dy * sz + (if dy != 0 then 0 else off);
          # Short on the left, where the wordmark is, and above the footer.
          reach =
            if dx < 0 then
              110
            else if dx > 0 then
              220
            else if dy > 0 then
              120
            else
              150;
          # Outer pins bend sooner and further out, so no two traces cross.
          k = (i - 5) * 14;
          a = abs k;
          l1 = 12 + (5 - abs (i - 5)) * 6 + rand h 0 * 6;
          l3 = 20 + rand h 1 * (reach - 60);
          qx = if dx != 0 then 0 else 1;
          qy = if dx != 0 then 1 else 0;
          x1 = x + dx * l1;
          y1 = y + dy * l1;
          x2 = x1 + dx * a + qx * k;
          y2 = y1 + dy * a + qy * k;
          x3 = x2 + dx * l3;
          y3 = y2 + dy * l3;
          pick = rand h 2;
          col =
            if pick < 0.14 then
              p.magenta
            else if pick < 0.26 then
              p.green
            else
              p.cyan;
          op = if col == p.cyan then 0.4 else 0.85;
        in
        {
          path = ''<path d="M${s x} ${s y}L${s x1} ${s y1}L${s x2} ${s y2}L${s x3} ${s y3}" stroke="#${col}" stroke-opacity="${s op}"/>'';
          via = ''<circle cx="${s x3}" cy="${s y3}" r="2.2" fill="#${p.base}" stroke="#${col}" stroke-opacity="${s (op + 0.15)}"/>'';
        };
      pins = lib.concatMap (side: lib.genList (pin side) 11) [
        [
          1
          0
        ]
        [
          (-1)
          0
        ]
        [
          0
          1
        ]
        [
          0
          (-1)
        ]
      ];
    in
    {
      dy = 0;
      defs = "";
      body = ''
        <rect width="${s vw}" height="480" fill="url(#dots)"/>
        <g fill="none" stroke-width="1.2" stroke-linejoin="round">
        ${lib.concatMapStringsSep "\n" (t: t.path) pins}
        </g>
        <g stroke-width="1.2">
        ${lib.concatMapStringsSep "\n" (t: t.via) pins}
        </g>
        <rect x="${s (cx - sz)}" y="${s (cy - sz)}" width="${s (2 * sz)}" height="${s (2 * sz)}" fill="#${p.mantle}" stroke="#${p.cyan}" stroke-width="1.5"/>
        <rect x="${s (cx - sz + 8)}" y="${s (cy - sz + 8)}" width="${s (2 * sz - 16)}" height="${s (2 * sz - 16)}" fill="none" stroke="#${p.overlay}" stroke-width="0.8"/>
        <circle cx="${s (cx - sz + 16)}" cy="${s (cy - sz + 16)}" r="2.5" fill="#${p.magenta}"/>
        <text x="${s cx}" y="${s (cy + 3)}" text-anchor="middle" font-family="${font}" font-weight="800" font-size="17" letter-spacing="2" fill="#${p.bright}">${lib.toUpper (lib.last tags)}</text>
        <text x="${s cx}" y="${s (cy + 20)}" text-anchor="middle" font-family="${font}" font-size="8" letter-spacing="1.5" fill="#${p.subtext}">${lib.toUpper (builtins.head tags)}</text>
      '';
    };

  # --- sweep: a radar scope with the other hosts as labelled contacts ---------
  sweep =
    let
      cx = vw - 233;
      cy = 245;
      r = 180;
      at = deg: dist: {
        x = cx + dist * cos (rad deg);
        y = cy + dist * sin (rad deg);
      };
      rot = deg: ''transform="rotate(${s deg} ${s cx} ${s cy})"'';
      rings = lib.concatMapStrings (
        q:
        ''<circle cx="${s cx}" cy="${s cy}" r="${s q}" fill="none" stroke="#${p.cyan}" stroke-opacity="${
          if q == r then "0.55" else "0.22"
        }"/>''
      ) [ 45 90 135 180 ];
      ticks = lib.concatStrings (
        lib.genList (
          i:
          let
            big = lib.mod i 6 == 0;
          in
          ''<line x1="${s (cx + r)}" y1="${s cy}" x2="${s (cx + r + (if big then 9 else 4))}" y2="${s cy}" stroke="#${p.cyan}" stroke-opacity="${
            if big then "0.7" else "0.35"
          }" ${rot (i * 5)}/>''
        ) 72
      );
      # The afterglow: sixteen 4-degree wedges behind the sweep line, fading out.
      edge = at (-4) r;
      wedges = lib.concatStrings (
        lib.genList (
          i:
          ''<path d="M${s cx} ${s cy}L${s (cx + r)} ${s cy}A${s r} ${s r} 0 0 0 ${s edge.x} ${s edge.y}Z" fill="#${p.green}" fill-opacity="${
            s (0.2 * (1 - i / 16.0))
          }" ${rot (-40 - i * 4)}/>''
        ) 16
      );
      blip =
        deg: dist: col: name:
        let
          c = at deg dist;
        in
        ''
          <circle cx="${s c.x}" cy="${s c.y}" r="7" fill="#${col}" fill-opacity="0.15"/>
          <circle cx="${s c.x}" cy="${s c.y}" r="2.6" fill="#${col}"/>
        ''
        + lib.optionalString (name != "") ''
          <text x="${s (c.x + 10)}" y="${s (c.y + 3)}" font-family="${font}" font-size="9" letter-spacing="1" fill="#${p.text}">${name}</text>
        '';
      # Where the first four peers go; any more are left off.
      slots = [
        (blip (-72) 118 p.cyan)
        (blip (-150) 150 p.cyan)
        (blip 160 105 p.cyan)
        (blip 68 150 p.cyan)
      ];
    in
    {
      dy = 0;
      defs = "";
      body = ''
        ${rings}
        ${ticks}
        <path d="M${s (cx - r)} ${s cy}H${s (cx + r)}M${s cx} ${s (cy - r)}V${s (cy + r)}" stroke="#${p.cyan}" stroke-opacity="0.18"/>
        ${wedges}
        <line x1="${s cx}" y1="${s cy}" x2="${s (cx + r)}" y2="${s cy}" stroke="#${p.green}" stroke-width="1.5" ${rot (-40)}/>
        ${lib.concatStrings (lib.zipListsWith (slot: name: slot name) slots peers)}
        ${blip 35 96 p.overlay ""}
        ${blip 118 142 p.magenta ""}
        ${blip (-12) 160 p.overlay ""}
        <circle cx="${s cx}" cy="${s cy}" r="3" fill="#${p.bright}"/>
      '';
    };

  # --- hexdump: a memory dump with the hostname readable in one row -----------
  hexdump =
    let
      x0 = vw - 453; # 78 characters at 5.4 units end 32 from the right edge
      marked = 13;
      label = builtins.substring 0 16 "${hostname} // ${lib.last tags}                ";
      letters = lib.stringToCharacters "abcdefghijklmnopqrstuvwxyz";
      hexN = width: n: lib.toLower (lib.fixedWidthString width "0" (lib.toHexString n));
      group =
        bytes: "${lib.concatStringsSep " " (lib.take 8 bytes)}  ${lib.concatStringsSep " " (lib.drop 8 bytes)}";
      ascii =
        v:
        if v >= 97 && v <= 122 then
          builtins.elemAt letters (v - 97)
        else if v >= 48 && v <= 57 then
          s (v - 48)
        else
          ".";
      row =
        i:
        let
          # The first half of the hash is the row's 16 bytes; the second half
          # zeroes about one in five of them, as real memory would be.
          h = hash "hexdump:${s i}";
          bytes = lib.genList (
            j: if hex (builtins.substring (32 + j * 2) 2 h) < 51 then "00" else builtins.substring (j * 2) 2 h
          ) 16;
          addr = hexN 8 (18976 + i * 16);
          open = ''<text x="${s x0}" y="${s (74 + i * 12)}" xml:space="preserve"'';
        in
        if i == marked then
          ''${open} fill="#${p.subtext}">${addr}  <tspan fill="#${p.cyan}">${
            group (map (c: hexN 2 (lib.strings.charToInt c)) (lib.stringToCharacters label))
          }</tspan>  |<tspan fill="#${p.magenta}">${label}</tspan>|</text>''
        else
          ''${open}>${addr}  ${group bytes}  |${lib.concatMapStrings (b: ascii (hex b)) bytes}|</text>'';
    in
    {
      dy = 0;
      defs = ''
        <linearGradient id="dumpFade" gradientUnits="userSpaceOnUse" x1="${s (vw - 468)}" y1="0" x2="${s (vw - 293)}" y2="0">
          <stop offset="0" stop-color="#fff" stop-opacity="0.12"/>
          <stop offset="1" stop-color="#fff" stop-opacity="1"/>
        </linearGradient>
        <mask id="dumpMask">
          <rect width="${s vw}" height="480" fill="url(#dumpFade)"/>
        </mask>
      '';
      body = ''
        <g mask="url(#dumpMask)" font-family="${font}" font-size="9" fill="#${p.overlay}">
        ${lib.concatStringsSep "\n" (lib.genList row 31)}
        </g>
      '';
    };

  # --- skyline: a night skyline standing on the grid's horizon ----------------
  skyline =
    let
      # Lays buildings left to right until the canvas is full; `mk i x` returns
      # the i-th building's svg and how far it moves x.
      street =
        start: count: mk:
        (lib.foldl'
          (
            acc: i:
            if acc.x >= vw then
              acc
            else
              let
                b = mk i acc.x;
              in
              {
                x = acc.x + b.advance;
                out = acc.out + b.svg;
              }
          )
          {
            x = start;
            out = "";
          }
          (lib.range 0 (count - 1))
        ).out;

      back = street (-10.0) 80 (
        i: x:
        let
          h = hash "sky:back:${s i}";
          w = 18 + rand h 0 * 30;
          ht = 26 + rand h 1 * 70 + 50 * gauss ((x - (vw - 253)) / 200.0);
        in
        {
          advance = w + rand h 2 * 4;
          svg = ''<rect x="${s x}" y="${s (horizon - ht)}" width="${s w}" height="${s ht}"/>'';
        }
      );

      front = street (-6.0) 60 (
        i: x:
        let
          h = hash "sky:front:${s i}";
          w = 26 + builtins.floor (rand h 0 * 5) * 7;
          # Tall towers only on the right, away from the wordmark.
          ht = 18 + rand h 1 * 50 + 120 * rand h 2 * gauss ((x - (vw - 243)) / 150.0);
          top = horizon - ht;
          mid = x + w / 2.0;
          window =
            c: r:
            let
              hw = hash "sky:win:${s i}:${s c}:${s r}";
              k = rand hw 0;
              col =
                if k < 0.2 then
                  p.amber
                else if k < 0.26 then
                  p.cyan
                else
                  p.magenta;
            in
            lib.optionalString (k < 0.3)
              ''<rect x="${s (x + 5 + c * 7)}" y="${s (top + 6 + r * 8)}" width="3" height="4" fill="#${col}" fill-opacity="${
                s (0.35 + rand hw 1 * 0.6)
              }" stroke="none"/>'';
          cols = builtins.floor ((w - 11) / 7.0) + 1;
          rows = builtins.floor ((ht - 12.5) / 8) + 1;
        in
        {
          advance = w + 2 + rand h 3 * 10;
          svg = ''
            <rect x="${s x}" y="${s top}" width="${s w}" height="${s ht}"/>
          ''
          + lib.optionalString (ht > 110) ''
            <path d="M${s mid} ${s top}v-16"/>
            <circle cx="${s mid}" cy="${s (top - 17)}" r="1.4" fill="#${p.red}" stroke="none"/>
          ''
          + lib.concatStrings (lib.genList (c: lib.concatStrings (lib.genList (window c) rows)) cols);
        }
      );
    in
    {
      dy = -74;
      defs = "";
      body = ''
        <ellipse cx="${s (vw - 293)}" cy="${s horizon}" rx="400" ry="150" fill="url(#haze)"/>
        <g fill="#${p.surface}" fill-opacity="0.55">
        ${back}
        </g>
        <g fill="#${p.void}" stroke="#${p.cyan}" stroke-opacity="0.3" stroke-width="0.8">
        ${front}
        </g>
        <rect x="0" y="${s horizon}" width="${s vw}" height="${s (480 - horizon)}" fill="#${p.void}"/>
        <g mask="url(#floorMask)" stroke="#${p.cyan}" stroke-opacity="0.4" stroke-width="1">
        ${floorLines}
        </g>
        <rect x="0" y="${s horizon}" width="${s vw}" height="1.2" fill="url(#horizonLine)"/>
      '';
    };
in
{
  inherit
    ridgeline
    traces
    sweep
    hexdump
    skyline
    ;
}
