{ pkgs, ... }:

let
  # power-profiles-daemon never changes profile by itself, so the laptop sat
  # on "balanced" whatever it was running from. This picks power-saver on
  # battery and balanced on AC. A profile chosen by hand lasts until the next
  # plug or unplug.
  #
  # power-saver leaves turbo on, so battery also turns that off: the CPU stays
  # at or below its base frequency, giving up some burst speed for the least
  # efficient part of its range.
  powerProfileAuto = pkgs.writeShellApplication {
    name = "power-profile-auto";
    runtimeInputs = [ pkgs.power-profiles-daemon ];
    text = ''
      profile=power-saver
      no_turbo=1
      for supply in /sys/class/power_supply/*; do
        if [[ $(<"$supply/type") == Mains && $(<"$supply/online") == 1 ]]; then
          profile=balanced
          no_turbo=0
        fi
      done
      powerprofilesctl set "$profile"
      echo "$no_turbo" > /sys/devices/system/cpu/intel_pstate/no_turbo
    '';
  };
in
{
  # NetworkManager and desktop environments use libinput automatically.
  services.libinput.enable = true;

  # Preserve battery life when the laptop is not connected to AC power.
  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;

  # Runs once at boot, and again from udev whenever the charger comes or goes.
  # udev starts the unit rather than running the script itself: its boot-time
  # events arrive before power-profiles-daemon is up.
  systemd.services.power-profile-auto = {
    description = "Match the power profile to the power source";
    after = [ "power-profiles-daemon.service" ];
    requires = [ "power-profiles-daemon.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${powerProfileAuto}/bin/power-profile-auto";
    };
  };
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="${pkgs.systemd}/bin/systemctl start --no-block power-profile-auto.service"
  '';

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
    # On battery, a closed lid suspends to RAM and, if it is still shut an hour
    # later, wakes just long enough to hibernate (see HibernateDelaySec). On AC
    # there is nothing to save, so it stays in RAM and wakes instantly.
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend";
    # "Docked" includes having a second display connected: keep working on it.
    HandleLidSwitchDocked = "ignore";
    # The 30s default swallows a lid close that follows shortly after a wake.
    HoldoffTimeoutSec = "5s";
  };
  systemd.sleep.settings.Sleep.HibernateDelaySec = "1h";
}
