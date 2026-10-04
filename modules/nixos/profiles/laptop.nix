{
  # NetworkManager and desktop environments use libinput automatically.
  services.libinput.enable = true;

  # Preserve battery life when the laptop is not connected to AC power.
  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;

  # logind is the only thing allowed to act on the lid switch. Cinnamon's
  # csd-power was handling it too, and the two requests did not line up: logind
  # suspended on lid close, and csd-power's suspend landed about a second after
  # the machine had already resumed on lid open, so it dropped straight back to
  # sleep. csd-power's `handle-lid-switch` inhibitor also comes and goes (it
  # only takes it with an external monitor attached), so some lid closes were
  # ignored by logind and then dropped by csd-power, leaving the laptop awake
  # with the lid shut. Cinnamon's side is turned off in
  # home/boboysdadda/cinnamon.nix.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    # "Docked" includes having a second display connected: keep working on it.
    HandleLidSwitchDocked = "ignore";
    # The 30s default swallows a lid close that follows shortly after a wake.
    HoldoffTimeoutSec = "5s";
  };
}
