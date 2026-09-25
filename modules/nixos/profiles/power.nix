# Power management to stretch the PocketTerm35's 5000mAh battery.
{
  pkgs,
  ...
}:

let
  # `pwrmode saver|normal|toggle|status`: battery saver. Saver pins the CPU to
  # its lowest step (powersave governor, 1.5 GHz; the ceiling is already capped
  # at 1.8 GHz in config.txt) and powers the Bluetooth radio off. Normal goes
  # back to schedutil and leaves Bluetooth off; turn it on from btmenu when
  # needed. Toggled from the power menu. Not persistent: a reboot is normal.
  pwrmode = pkgs.writeShellApplication {
    name = "pwrmode";
    runtimeInputs = with pkgs; [
      bluez
      coreutils
    ];
    text = ''
      gov=/sys/devices/system/cpu/cpufreq/policy0/scaling_governor

      status() {
        if [ "$(cat "$gov")" = powersave ]; then echo saver; else echo normal; fi
      }

      # The setuid wrapper; pkgs.sudo on PATH can't elevate.
      set_gov() { echo "$1" | /run/wrappers/bin/sudo tee "$gov" >/dev/null; }

      case "''${1:-status}" in
        saver)
          set_gov powersave
          bluetoothctl power off >/dev/null 2>&1 || true
          ;;
        normal) set_gov schedutil ;;
        toggle)
          if [ "$(status)" = saver ]; then "$0" normal; else "$0" saver; fi
          ;;
        status) status ;;
        *)
          echo "usage: pwrmode [saver|normal|toggle|status]" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  powerManagement = {
    enable = true;
    # schedutil scales CPU frequency with load (1.5-1.8 GHz under the
    # config.txt cap) for the best battery/responsiveness balance. It is
    # already the vendor-kernel default; set explicitly so it stays that way
    # across rebuilds. `pwrmode saver` switches to powersave at runtime.
    cpuFreqGovernor = "schedutil";
  };

  # Wi-Fi radio power saving. Safe on this device: the keyboard/trackpad/touch
  # are all on USB (RP2040) and I2C, so Wi-Fi powersave won't affect input.
  networking.networkmanager.wifi.powersave = true;

  # Bluetooth radio stays off until turned on from btmenu (Super+B).
  hardware.bluetooth.powerOnBoot = false;

  environment.systemPackages = [ pwrmode ];
}
