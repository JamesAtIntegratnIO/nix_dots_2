# Emulation

RetroArch (libretro) scales cleanly to 640x480. Launch with `Super+g`.

## The catch: the buttons are keyboard keys

The chassis game controls are **not a gamepad** — they send keyboard keycodes,
and two are quirky. The config already maps them correctly; this is just so the
behavior isn't a mystery:

- **X and Y are physically swapped** (the key under "X" sends Y's code, and
  vice-versa) — remapped in config so the labels are right in games.
- **Start** = the `Pause` key.
- **Select** = the `SysRq` key (not Print Screen).

## Menu & hotkeys

- **Open the in-game menu:** hold **Select**, then tap **Start**.
  (Select is the hotkey-enable key; Start is the menu toggle.)
- Game Focus is deliberately **off** — turning it on would block the
  keyboard-mapped pad, since the "gamepad" *is* the keyboard.

## Library

- ROMs live in **`~/ROMs`** (`/home/jdreier/ROMs`) — that's the browser's start
  directory.
- Box art auto-downloads while you browse (right thumbnail = boxart, left =
  title screen), so you need network for art but not to play.
- Menu is **RGUI** (the crisp pixel menu) in the cyberdeck palette — Ozone/XMB
  are built for 1080p and look rough here.

## Cores installed

NES (fceumm, nestopia) · SNES (snes9x) · Game Boy / Color (gambatte) · GBA
(mGBA) · SMS / Game Gear / Genesis (genesis-plus-gx) · Genesis / 32X / SegaCD
(picodrive) · PlayStation (pcsx-rearmed) · N64 (mupen64plus) · Atari 2600
(stella) · arcade (mame2003-plus).
