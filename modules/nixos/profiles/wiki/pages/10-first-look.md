# First look

Raspberry Pi 5 (16GB) in a Waveshare handheld chassis: 3.5" 640x480
touchscreen, built-in QWERTY keyboard, game pad (D-pad, ABXY, shoulders).

## Power button

| Action | Result |
|--------|--------|
| Short press | Power menu (lock / log out / reboot / off) |
| Long hold | Hard power-off in firmware (last resort) |

Boots into Sway, auto-logged in as `jdreier`. Console has no password; SSH is
key-only.

## Input map

| Input | Handled by | Notes |
|-------|-----------|-------|
| Keyboard | RP2040 MCU (USB2/dwc2 host) | Normal USB keyboard |
| Fn + brightness | RP2040 hardware PWM | No OS/CLI control (see *display-power*) |
| Function row | `XF86Audio*` keys | Volume / media |
| Touch | Goodix GT911 (I2C-1) | Tap = left click; single tap opens files |
| Edge swipes | lisgd | Gestures only from a screen edge (see *desktop-sway*) |
| Game buttons | Keyboard keys | X/Y swapped, Start=Pause, Select=SysRq (see *emulation*) |

## Verify hardware

    i2cdetect -y 1        # 0x5d = GT911 touch (UU), 0x15/0x17 = keyboard MCU
    wpctl status          # audio graph; HDMI sink should be default
    swaymsg -t get_outputs | grep -E 'Output|power'

## Audio path

Stereo speaker + 3.5mm jack via PipeWire. Audio rides the HDMI signal (same
cable as the panel); no GPIO DAC, so HDMI is the only sink.

    wpctl status                                   # list sinks
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 50%      # set level
