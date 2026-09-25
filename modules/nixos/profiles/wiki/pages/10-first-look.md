# First look

The physical PocketTerm35: Raspberry Pi 5 (16GB) in a Waveshare handheld
chassis with a 3.5" 640x480 touchscreen, a built-in QWERTY keyboard, and a
game pad (D-pad, ABXY, shoulder buttons).

## Powering on / off

- **Power button, short press** → opens the on-screen **power menu** (lock,
  log out, reboot, power off). logind is told to ignore the key so it does
  *not* suspend/kill on a tap.
- **Power button, long hold** → hard power-off in firmware (last resort).
- It boots straight into Sway, auto-logged-in as `jdreier` (greetd). No
  password prompt on the console; SSH is key-only.

## Keyboard

- Driven by an on-board **RP2040** MCU on the Pi's internal USB2 (dwc2 in
  host mode) — it enumerates as a normal USB keyboard.
- **Fn + brightness keys** adjust the panel backlight directly in the RP2040
  (hardware PWM). There is no Sway binding for it — see *Display & power*.
- The function row also sends volume / media `XF86Audio*` keys (see *Desktop*).

## Touchscreen

- **Goodix GT911** on I2C-1. Taps are a left click; drag to select text.
- **Single tap opens** files and folders (pcmanfm and rofi are configured for
  single-click, since a finger's double-tap lands too far apart to register).
- **Edge swipes** are gestures (lisgd) — see *Desktop (Sway) → Gestures*.
  In-app scrolling/dragging is untouched; only swipes that *start at an edge*
  are captured.
- Pinch-zoom and kinetic scroll work in Firefox.

## Game buttons

They are **keyboard keys**, not a gamepad device — this matters for
RetroArch. X/Y are physically swapped, Start = Pause key, Select = SysRq.
See *Emulation* for the full mapping.

## Audio

Stereo speaker + 3.5mm jack via PipeWire. Audio is extracted from the **HDMI**
signal (same cable that drives the panel) — there's no GPIO DAC. HDMI is the
only real sink, so it's the default.
