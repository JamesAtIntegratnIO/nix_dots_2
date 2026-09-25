# Procedural 640x480 cyberdeck wallpaper, rendered from SVG at build time so
# it tracks the palette and needs no binary in git. The top 24px sit under
# Waybar, so nothing important is drawn there.
{
  pkgs,
  palette,
  hostname ? "pocketterm",
}:

let
  p = palette;
  font = "JetBrainsMono Nerd Font";

  # Perspective floor: horizontal lines bunch up toward the horizon, vertical
  # lines fan out from a vanishing point just above it.
  horizon = 336;
  floorLines = builtins.concatStringsSep "\n" (
    map (
      k:
      let
        y = horizon + k * k * 0.95;
      in
      ''<line x1="0" y1="${toString y}" x2="640" y2="${toString y}"/>''
    ) (builtins.genList (k: k + 1) 15)
  );
  rays = builtins.concatStringsSep "\n" (
    map (
      i: ''<line x1="320" y1="${toString (horizon - 30)}" x2="${toString (320 + i * 150)}" y2="480"/>''
    ) (builtins.genList (i: i - 16) 33)
  );

  # Prompt line under the wordmark; the block cursor sits right after it
  # (JetBrains Mono advances 0.6em, so 7.8px per char at 13px; "❯" is 3
  # bytes but one glyph, hence the -2).
  prompt = "❯ nixos // aarch64 // rpi5 // ${hostname}";
  cursorX = 58 + (builtins.stringLength prompt - 2) * 7.8 + 4;

  # L-shaped HUD corner marks.
  corner = x: y: dx: dy: ''
    <path d="M ${toString x} ${toString (y + dy * 14)} L ${toString x} ${toString y} L ${toString (x + dx * 14)} ${toString y}"/>
  '';

  svg = pkgs.writeText "pocketterm-wall.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="640" height="480" viewBox="0 0 640 480">
      <defs>
        <radialGradient id="bg" cx="36%" cy="40%" r="75%">
          <stop offset="0" stop-color="#${p.mantle}"/>
          <stop offset="0.55" stop-color="#${p.base}"/>
          <stop offset="1" stop-color="#${p.void}"/>
        </radialGradient>
        <pattern id="dots" width="16" height="16" patternUnits="userSpaceOnUse">
          <circle cx="8" cy="8" r="0.7" fill="#${p.overlay}" fill-opacity="0.45"/>
        </pattern>
        <pattern id="scan" width="4" height="3" patternUnits="userSpaceOnUse">
          <rect width="4" height="1" fill="#000" fill-opacity="0.28"/>
        </pattern>
        <linearGradient id="floorFade" x1="0" y1="${toString horizon}" x2="0" y2="480" gradientUnits="userSpaceOnUse">
          <stop offset="0" stop-color="#fff" stop-opacity="0"/>
          <stop offset="1" stop-color="#fff" stop-opacity="1"/>
        </linearGradient>
        <mask id="floorMask">
          <rect x="0" y="${toString horizon}" width="640" height="${toString (480 - horizon)}" fill="url(#floorFade)"/>
        </mask>
        <linearGradient id="dotFade" x1="0" y1="0" x2="0" y2="${toString horizon}" gradientUnits="userSpaceOnUse">
          <stop offset="0" stop-color="#fff" stop-opacity="1"/>
          <stop offset="1" stop-color="#fff" stop-opacity="0.1"/>
        </linearGradient>
        <mask id="dotMask">
          <rect width="640" height="${toString horizon}" fill="url(#dotFade)"/>
        </mask>
        <linearGradient id="horizonLine" x1="0" x2="1">
          <stop offset="0" stop-color="#${p.magenta}" stop-opacity="0"/>
          <stop offset="0.3" stop-color="#${p.magenta}"/>
          <stop offset="0.7" stop-color="#${p.cyan}"/>
          <stop offset="1" stop-color="#${p.cyan}" stop-opacity="0"/>
        </linearGradient>
        <radialGradient id="haze" cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stop-color="#${p.magenta}" stop-opacity="0.35"/>
          <stop offset="0.5" stop-color="#${p.purple}" stop-opacity="0.12"/>
          <stop offset="1" stop-color="#${p.purple}" stop-opacity="0"/>
        </radialGradient>
        <filter id="glow" x="-20%" y="-50%" width="140%" height="200%">
          <feGaussianBlur stdDeviation="6"/>
        </filter>
        <filter id="softGlow" x="-10%" y="-400%" width="120%" height="900%">
          <feGaussianBlur stdDeviation="3"/>
        </filter>
      </defs>

      <rect width="640" height="480" fill="url(#bg)"/>
      <rect width="640" height="${toString horizon}" fill="url(#dots)" mask="url(#dotMask)"/>

      <ellipse cx="400" cy="${toString horizon}" rx="300" ry="70" fill="url(#haze)"/>

      <!-- perspective floor -->
      <g mask="url(#floorMask)" stroke="#${p.cyan}" stroke-opacity="0.45" stroke-width="1">
        ${floorLines}
        ${rays}
      </g>

      <!-- horizon -->
      <rect x="0" y="${toString (horizon - 2)}" width="640" height="4" fill="url(#horizonLine)" filter="url(#softGlow)" opacity="0.9"/>
      <rect x="0" y="${toString horizon}" width="640" height="1" fill="url(#horizonLine)"/>

      <!-- wordmark -->
      <rect x="40" y="170" width="3" height="58" fill="#${p.cyan}"/>
      <text x="56" y="214" font-family="${font}" font-weight="800" font-size="46" letter-spacing="3"
            fill="#${p.cyan}" opacity="0.75" filter="url(#glow)">POCKETTERM</text>
      <text x="56" y="214" font-family="${font}" font-weight="800" font-size="46" letter-spacing="3"
            fill="#${p.bright}">POCKETTERM</text>
      <text x="58" y="244" font-family="${font}" font-size="13" fill="#${p.subtext}">
        <tspan fill="#${p.green}">❯</tspan> nixos <tspan fill="#${p.overlay}">//</tspan> aarch64 <tspan fill="#${p.overlay}">//</tspan> rpi5 <tspan fill="#${p.overlay}">//</tspan> ${hostname}</text>
      <rect x="${toString cursorX}" y="233" width="8" height="14" fill="#${p.magenta}"/>

      <!-- HUD furniture -->
      <g stroke="#${p.cyan}" stroke-opacity="0.6" stroke-width="1.5" fill="none">
        ${corner 12 36 1 1}
        ${corner 628 36 (-1) 1}
        ${corner 12 468 1 (-1)}
        ${corner 628 468 (-1) (-1)}
      </g>
      <g font-family="${font}" font-size="9" letter-spacing="1">
        <text x="30" y="48" fill="#${p.overlay}">NODE::0x35</text>
        <text x="610" y="48" fill="#${p.green}" text-anchor="end">● SYS ONLINE</text>
        <text x="30" y="460" fill="#${p.overlay}">640×480 · ARM64 · WAYLAND</text>
        <text x="610" y="460" fill="#${p.magenta}" fill-opacity="0.8" text-anchor="end">AUTHORIZED USE ONLY</text>
      </g>

      <rect width="640" height="480" fill="url(#scan)"/>
    </svg>
  '';
in
pkgs.runCommand "pocketterm-wallpaper.png" { nativeBuildInputs = [ pkgs.resvg ]; } ''
  resvg --skip-system-fonts \
    --use-fonts-dir ${pkgs.nerd-fonts.jetbrains-mono}/share/fonts \
    ${svg} $out
''
