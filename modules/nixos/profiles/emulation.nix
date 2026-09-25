# Emulation for the PocketTerm35's built-in game controls (D-pad, ABXY,
# shoulders). Those buttons enumerate as keyboard keys (there is no gamepad
# device), with X/Y sending swapped keycodes and Start/Select = Pause/SysRq.
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
        # Under Sway the Wayland GL context ignores this and always uses its own
        # "wayland" input driver (raw evdev keycodes from the compositor). udev
        # only matters if RetroArch is ever run on KMS outside the compositor;
        # the default "x" reads nothing either way.
        input_driver = "udev";

        # Built-in controls are keyboard keys. Physical X/Y send swapped codes;
        # Start = KEY_PAUSE ("pause"), Select = KEY_SYSRQ ("sysreq" -- NOT
        # "print_screen", which is KEY_PRINT and never fires). Verified by
        # logging event0 while pressing each button.
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
        input_player1_start = "pause";
        input_player1_select = "sysreq";
        # Hold Select + press Start to open the menu in-game. (Holding the
        # hotkey-enable key blocks game input, so Select only reaches the game
        # as a quick tap.)
        input_enable_hotkey = "sysreq";
        input_menu_toggle = "pause";
        # Keep Game Focus off: it blocks every keyboard-mapped RetroPad bind
        # and hotkey, and our "gamepad" IS the keyboard.
        input_auto_game_focus = "0";

        # Library: boxart auto-downloads while browsing; browse from ~/ROMs.
        network_on_demand_thumbnails = "true";
        thumbnails = "3"; # right thumbnail = boxart
        left_thumbnails = "2"; # left = title screen
        rgui_browser_directory = "/home/jdreier/ROMs";
      };
    })
  ];
}
