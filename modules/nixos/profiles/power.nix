# Power management to stretch the PocketTerm35's 5000mAh battery.
{
  ...
}:

{
  powerManagement = {
    enable = true;
    # schedutil scales CPU frequency with load (1.5-2.4 GHz on the Pi 5) for the
    # best battery/responsiveness balance. It is already the vendor-kernel
    # default; set explicitly so it stays that way across rebuilds.
    cpuFreqGovernor = "schedutil";
  };

  # Wi-Fi radio power saving. Safe on this device: the keyboard/trackpad/touch
  # are all on USB (RP2040) and I2C, so Wi-Fi powersave won't affect input.
  networking.networkmanager.wifi.powersave = true;
}
