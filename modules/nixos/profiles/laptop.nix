{
  # NetworkManager and desktop environments use libinput automatically.
  services.libinput.enable = true;

  # Preserve battery life when the laptop is not connected to AC power.
  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;
}
