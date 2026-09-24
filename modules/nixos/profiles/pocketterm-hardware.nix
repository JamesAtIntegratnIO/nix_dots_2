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

let
  # Waveshare's 3.5" HDMI/touch overlay bundle. The `-5b` variant is the one to
  # use even on a Pi 4B: it declares the GT911 at both 0x14 and 0x5d, whereas
  # the `-4b` variant only declares 0x14, and the panel answers at 0x5d.
  waveshareDtbo = pkgs.fetchzip {
    url = "https://files.waveshare.com/wiki/common/3.5HDMI_E_DTBO.zip";
    hash = "sha256-JBSnjkm7STjq83rJMtJX/CBP7GLUSR4Eux5b2Vp1KwE=";
    stripRoot = true;
  };
in
{
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.display-vc4 # panel is on HDMI (vc4-kms-v3d), not the RP1.
    raspberry-pi-5.bluetooth
  ];

  # Generation-aware bootloader (the base module still defaults to the
  # deprecated "kernelboot" for the Pi 5).
  boot.loader.raspberry-pi.bootloader = "kernel";

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
  };

  # Apply the touch overlay at build time so the compiled DTB already targets
  # i2c1/gpio; no need to drop a .dtbo into the firmware partition by hand.
  hardware.deviceTree.overlays = [
    {
      name = "waveshare-pocketterm35-touch";
      dtboFile = "${waveshareDtbo}/waveshare-35dpi-5b.dtbo";
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
