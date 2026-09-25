# Emulation for the PocketTerm35's built-in game controls (D-pad, ABXY,
# shoulders). Those buttons enumerate as keyboard keys (there is no gamepad
# device), with X/Y sending swapped keycodes and Start/Select = SysRq/Pause.
#
# RetroArch is a libretro frontend that scales cleanly to the 640x480 panel.
# Input + library settings are baked into the wrapper's appendconfig (loaded
# after retroarch.cfg and never written back), so they survive a reflash and
# can't be clobbered by RetroArch's save-on-exit. Cores span NES..PS1/N64.
{
  pkgs,
  ...
}:

{
  environment.systemPackages = [
    (pkgs.retroarch-bare.wrapper {
      cores = with pkgs.libretro; [
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
      ];

      settings = {
        # REQUIRED under Wayland: the default "x" (X11) input driver reads no
        # input on the Pi 5's Wayland session -- this cost a long debug once.
        input_driver = "udev";

        # Built-in controls are keyboard keys. Physical X/Y send swapped codes;
        # Start = SysRq (print_screen), Select = Pause. Verified via evtest.
        input_player1_a = "a";
        input_player1_b = "b";
        input_player1_x = "y";
        input_player1_y = "x";
        input_player1_up = "up";
        input_player1_down = "down";
        input_player1_left = "left";
        input_player1_right = "right";
        input_player1_l = "l";
        input_player1_r = "r";
        input_player1_start = "print_screen";
        input_player1_select = "pause";
        # Hold Select + press Start to open the menu in-game.
        input_enable_hotkey = "pause";
        input_menu_toggle = "print_screen";

        # Library: boxart auto-downloads while browsing; browse from ~/ROMs.
        network_on_demand_thumbnails = "true";
        thumbnails = "3"; # right thumbnail = boxart
        left_thumbnails = "2"; # left = title screen
        rgui_browser_directory = "/home/jdreier/ROMs";
      };
    })
  ];
}
