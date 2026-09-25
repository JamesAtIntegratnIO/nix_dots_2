# Display & power

## Brightness

Two layers. The hardware backlight saves battery; the overlay only darkens the
image.

| Keys | Command | Layer |
|------|---------|-------|
| `Fn + brightness` | (none; RP2040 hardware PWM) | Backlight; saves power |
| `Super+minus` | `screen-dim down` | Overlay ×0.75 |
| `Super+equal` | `screen-dim up` | Overlay brighter |
| `Super+0` | `screen-dim reset` | Overlay full |

The overlay is comfort only (LEDs stay lit). vc4 exposes no gamma LUT, so
gamma-based dimmers don't work here.

## Panel & lock

    panel-power off                             # blank the panel
    panel-power on                              # wake it (retries vc4's flaky wake)
    swaylock -f -C /etc/swaylock/config         # lock now
    swaymsg -t get_outputs | grep -A2 HDMI-A-1  # check power/mode state

Idle (swayidle): panel off at 3 min (any key/touch wakes), lock at 10 min.
Fullscreen apps (RetroArch, video) inhibit idle, so they never blank.

## Battery

No battery telemetry on this chassis (the hardware doesn't report a
percentage). Levers that help:

    pwrmode                     # saver | normal
    pwrmode saver               # CPU pinned to 1.5 GHz, Bluetooth off
    pwrmode normal              # back to schedutil (1.5-1.8 GHz)

Battery saver is also the last row of the power menu. It resets on reboot.
The CPU is capped at 1.8 GHz in config.txt (`arm_freq`), and Bluetooth is off
at boot (turn it on from `Super+b`).

Firmware (EEPROM) has `POWER_OFF_ON_HALT=1`, so a powered-off Pi draws
almost nothing even before the top button cuts power. Check with
`vcgencmd bootloader_config`.

Biggest wins, in order: lower the hardware backlight (`Fn`), quit fullscreen
emulators when idle, unplug USB peripherals (a Wi-Fi dongle or the Pager draw
real power). Wi-Fi power-save is on and safe (input is USB/I2C, not Wi-Fi).
