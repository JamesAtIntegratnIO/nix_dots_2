# Display & power

## Brightness (two layers)

1. **Hardware backlight** — `Fn + brightness keys` on the keyboard. The RP2040
   drives the backlight PWM directly; there's no Sway/OS binding. **This is the
   one that actually saves battery** — turn it down first.
2. **Software dim** — the hardware backlight has a floor that's still too bright
   at night, so a click-through black overlay scales the image darker on top:

   | Keys | Action |
   |------|--------|
   | `Super+minus` | Dim one step (×0.75) |
   | `Super+equal` | Brighten one step |
   | `Super+0` | Reset to full |

   This is **comfort only** — the LEDs stay lit, so it does *not* save power.
   (Gamma dimming isn't available: vc4 exposes no gamma LUT.)

## Idle, blank, and lock

Handled by swayidle:

- **3 min idle** → panel powers off. Any key or touch wakes it.
- **10 min idle** (or on sleep) → screen locks (swaylock).
- **Fullscreen apps** (RetroArch, video) hold an idle inhibitor, so games and
  movies never blank mid-use.

Panel wake on the Pi 5's vc4 HDMI is occasionally flaky, so the wake step
retries until the output reports powered — a dropped wake should recover on its
own within a second or two.

## Battery

- 5000 mAh cell. **There is no battery-level telemetry** exposed to the OS on
  this chassis — no percentage in the bar, by design (the hardware doesn't
  report it).
- CPU uses the `schedutil` governor (scales 1.5–2.4 GHz with load).
- Wi-Fi power-save is **on** (safe here — keyboard/touch are USB/I2C, not
  Wi-Fi, so input is unaffected).
- Biggest wins, in order: **lower the hardware backlight**, quit fullscreen
  emulators when idle, and unplug USB peripherals (a Wi-Fi dongle or the Pager
  draw real power).
