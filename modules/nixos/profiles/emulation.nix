# Emulation for the PocketTerm35's built-in game controls (D-pad, ABXY,
# shoulders). Those buttons enumerate as keyboard keys (there is no gamepad
# device), so map them once in RetroArch's input menu ("Bind All").
#
# RetroArch is a gamepad-driven libretro frontend that scales cleanly to the
# 640x480 panel. Cores span NES..PS1/N64, comfortably within the Pi 5's range;
# add or remove cores in the list below and redeploy.
{
  pkgs,
  ...
}:

{
  environment.systemPackages = [
    (pkgs.retroarch.withCores (
      cores: with cores; [
        fceumm # NES / Famicom
        nestopia # NES (alt, accurate)
        snes9x # SNES
        gambatte # Game Boy / Color
        mgba # Game Boy Advance
        genesis-plus-gx # SMS / Game Gear / Genesis
        picodrive # Genesis / 32X / SegaCD
        pcsx-rearmed # PlayStation (ARM-optimised)
        mupen64plus # Nintendo 64
        stella # Atari 2600
        mame2003-plus # arcade
      ]
    ))
  ];
}
