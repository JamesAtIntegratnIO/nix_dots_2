# First look

The physical PocketTerm35: Raspberry Pi 5 (16GB) in a Waveshare handheld
chassis with a 3.5" 640x480 touchscreen, a built-in QWERTY keyboard, and a
game pad (D-pad, ABXY, shoulder buttons).

## Powering on / off

- **Power button, short press** opens the on-screen **power menu** (lock, log
  out, reboot, power off). logind ignores the key, so a tap never suspends or
  kills the session.
- **Power button, long hold** forces a hard power-off in firmware (last resort).
- It boots into Sway, auto-logged in as `jdreier` (greetd). No password prompt
  on the console; SSH is key-only.

## Keyboard

- An on-board **RP2040** MCU drives it, on the Pi's internal USB2 (dwc2 in host
  mode). It enumerates as a normal USB keyboard.
- **Fn + brightness keys** set the panel backlight in the RP2040 (hardware PWM).
  No Sway binding covers this; see *Display & power*.
- The function row also sends volume / media `XF86Audio*` keys (see *Desktop*).

## Touchscreen

- **Goodix GT911** on I2C-1. A tap is a left click; drag to select text.
- **A single tap opens** files and folders (pcmanfm and rofi use single-click,
  since a finger's double-tap lands too far apart to register).
- **Edge swipes** are gestures (lisgd); see *Desktop (Sway) → Gestures*.
  In-app scrolling and dragging stay untouched, since only swipes that start at
  an edge get captured.
- Pinch-zoom and kinetic scroll work in Firefox.

## Game buttons

They are **keyboard keys**, not a gamepad device, which shapes how RetroArch
maps them: X/Y are physically swapped, Start = Pause key, Select = SysRq. See
*Emulation* for the full mapping.

## Audio

Stereo speaker + 3.5mm jack via PipeWire. The audio rides the **HDMI** signal
(the same cable that drives the panel); there's no GPIO DAC. HDMI is the only
real sink, so it's the default.
