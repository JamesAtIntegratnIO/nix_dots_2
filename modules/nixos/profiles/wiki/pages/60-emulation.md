# Emulation

RetroArch (libretro), scaled to 640x480.

    retroarch            # or Super+g; browse ~/ROMs from the menu
    ls ~/ROMs            # ROM library (browser starts here)

## Button map

The game controls send **keyboard keys**, not gamepad events. The config
already maps them; this is the mapping:

| Physical | Sends | RetroPad |
|----------|-------|----------|
| A / B | a / b | A / B |
| X / Y | swapped codes | remapped so labels match |
| D-pad | arrows | up/down/left/right |
| L / R | l / r | L / R |
| Start | `Pause` key | Start |
| Select | `SysRq` key | Select |

## In-game menu

Hold **Select**, then tap **Start**. (Select = hotkey-enable, Start = menu
toggle.) Game Focus stays off, since the keyboard *is* the pad.

## Library notes

- Menu is RGUI (crisp pixel menu) in the cyberdeck palette.
- Box art auto-downloads while browsing (needs network; playing doesn't).
- Cores: NES (fceumm, nestopia), SNES (snes9x), GB/GBC (gambatte), GBA (mGBA),
  SMS/GG/Genesis (genesis-plus-gx), Genesis/32X/SegaCD (picodrive), PS1
  (pcsx-rearmed), N64 (mupen64plus), Atari 2600 (stella), arcade (mame2003-plus).
