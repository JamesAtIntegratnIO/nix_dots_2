# Emulation

RetroArch (libretro) scales to 640x480. Launch with `Super+g`.

## The catch: the buttons are keyboard keys

The chassis game controls are **not a gamepad**. They send keyboard keycodes,
and two are quirky. The config already maps them right; this page explains why:

- **X and Y are physically swapped** (the key under "X" sends Y's code, and
  vice-versa). The config remaps them so the labels match in games.
- **Start** is the `Pause` key.
- **Select** is the `SysRq` key (not Print Screen).

## Menu & hotkeys

- **Open the in-game menu:** hold **Select**, then tap **Start**. (Select is the
  hotkey-enable key; Start is the menu toggle.)
- Game Focus stays **off**. Turning it on would block the keyboard-mapped pad,
  since the "gamepad" is the keyboard.

## Library

- ROMs live in **`~/ROMs`** (`/home/jdreier/ROMs`), the browser's start
  directory.
- Box art auto-downloads while you browse (right thumbnail = boxart, left =
  title screen), so art needs the network but playing doesn't.
- The menu is **RGUI**, the crisp pixel menu, in the cyberdeck palette. Ozone
  and XMB are built for 1080p and look rough here.

## Cores installed

NES (fceumm, nestopia), SNES (snes9x), Game Boy / Color (gambatte), GBA (mGBA),
SMS / Game Gear / Genesis (genesis-plus-gx), Genesis / 32X / SegaCD (picodrive),
PlayStation (pcsx-rearmed), N64 (mupen64plus), Atari 2600 (stella), arcade
(mame2003-plus).
