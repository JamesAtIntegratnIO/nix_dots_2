# PocketTerm35-specific hardware: Raspberry Pi 5 boot/firmware, the 640x480
# HDMI panel, and the Goodix GT911 touch controller.
#
# The `nixos-raspberrypi` modules (imported in the flake via
# `nixos-raspberrypi.lib.nixosSystem`) supply the vendor kernel, firmware, and
# `hardware.raspberry-pi.config` (config.txt) plumbing. This module layers on
# the panel and touch settings that are unique to the PocketTerm35 chassis.
{
  pkgs,
  nixos-raspberrypi,
  ...
}:

{
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.display-vc4 # panel is on HDMI (vc4-kms-v3d), not the RP1.
    raspberry-pi-5.bluetooth
  ];

  # Generation-aware bootloader (the base module still defaults to the
  # deprecated "kernelboot" for the Pi 5).
  boot.loader.raspberry-pi.bootloader = "kernel";

  # Audio: the chassis extracts audio from the HDMI signal (the same FPC that
  # drives the panel) and feeds the speaker amp -- there is NO I2S/PWM DAC on the
  # GPIO header. So do NOT add hifiberry-dac/audremap overlays; plain vc4 HDMI
  # audio (already provided by display-vc4) is the speaker path. PipeWire uses
  # the HDMI sink by default since it is the only real sink. Confirmed on device.

  # The panel supplies EDID over HDMI, but force the mode so it comes up at the
  # native 640x480 even before userspace reads the EDID.
  hardware.raspberry-pi.config.all = {
    options = {
      hdmi_force_hotplug = {
        enable = true;
        value = 1;
      };
    };
    base-dt-params = {
      # I2C-1 (GPIO2/3) carries the GT911 touch controller.
      i2c_arm = {
        enable = true;
        value = "on";
      };
    };
    dt-overlays = {
      # The built-in RP2040 keyboard/trackpad hangs off the Pi 5's internal USB2
      # (dwc2) controller, which must be put in host mode to enumerate it. The
      # base config only does this under [cm5], so the Pi 5 model B needs it here
      # -- without it there is no keyboard at all.
      dwc2 = {
        enable = true;
        params.dr_mode = {
          enable = true;
          value = "host";
        };
      };
    };
  };

  # Goodix GT911 touch controller on I2C-1, merged into the board DTB at build
  # time. This is Waveshare's `waveshare-35dpi-5b` overlay rewritten as source:
  # the shipped .dtbo declares `compatible = "brcm,bcm2835"` and the panel can
  # sit at either 0x14 or 0x5d, so both nodes are kept. `compatible` is set to
  # the Pi 5's `brcm,bcm2712` so nixpkgs' overlay applier actually matches it,
  # and `filter = "rpi-5-b"` scopes application to the Pi 5 model-B board DTBs
  # only -- without it the applier also tries `overlays/hat_map.dtb`, which is
  # itself an overlay and fails with FDT_ERR_BADOFFSET.
  hardware.deviceTree.overlays = [
    {
      name = "waveshare-pocketterm35-touch";
      filter = "rpi-5-b";
      dtsText = ''
        /dts-v1/;
        /plugin/;

        / {
          compatible = "brcm,bcm2712";

          fragment@0 {
            target = <&i2c1>;
            __overlay__ {
              #address-cells = <1>;
              #size-cells = <0>;
              status = "okay";

              gt911_14: gt911@14 {
                compatible = "goodix,gt911";
                reg = <0x14>;
                interrupt-parent = <&gpio>;
                interrupts = <4 2>;
                irq-gpios = <&gpio 4 2>;
                touchscreen-size-x = <640>;
                touchscreen-size-y = <480>;
                touchscreen-x-mm = <70>;
                touchscreen-y-mm = <53>;
              };

              gt911_5d: gt911@5d {
                compatible = "goodix,gt911";
                reg = <0x5d>;
                interrupt-parent = <&gpio>;
                interrupts = <4 2>;
                irq-gpios = <&gpio 4 2>;
                touchscreen-size-x = <640>;
                touchscreen-size-y = <480>;
                touchscreen-x-mm = <70>;
                touchscreen-y-mm = <53>;
              };
            };
          };
        };
      '';
    }
  ];

  # GT911 driver + I2C tools for poking at the touch/keyboard controllers
  # (`i2cdetect -y 1` should show UU at 0x5d for touch, and the RP2040 keyboard
  # MCU at 0x15 or 0x17).
  boot.kernelModules = [ "goodix" ];
  environment.systemPackages = [ pkgs.i2c-tools ];

  # udev groups referenced by the user definition.
  users.groups.i2c = { };
  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
  '';
}
