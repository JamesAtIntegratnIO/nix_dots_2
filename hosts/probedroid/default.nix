# Headless Raspberry Pi 5 (NVMe) that lives on Mom's LAN (192.168.1.0/24) so
# her network can be supported remotely over Tailscale.
#
# Built on the Mac Studio's linux-builder. The first install is a disk image
# (`.#packages.aarch64-linux.probedroid-image`) written straight to the NVMe drive;
# after that, deploy with `scripts/deploy-probedroid.sh`, which rolls back
# on its own if the new generation can't be reached.
{
  lib,
  pkgs,
  nixos-raspberrypi,
  ...
}:

let
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIESq1wdY7diOloASvawJgjjThP6kzDWC/J3NIzZu5QVe james@integratn.io";
in
{
  imports = [
    nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    ../../modules/nixos/core/locale.nix
    ../../modules/nixos/core/nix.nix
    ../../modules/nixos/profiles/tailscale.nix
    ./network.nix
    ./rustdesk.nix
    ./dropbox.nix
  ];

  networking.hostName = "probedroid";

  # Generation-aware bootloader (the base module still defaults to the
  # deprecated "kernelboot" for the Pi 5).
  boot.loader.raspberry-pi.bootloader = "kernel";

  # Matches the layout written by `.#probedroid-image`; mkDefault lets the
  # sd-image module own these while building the image itself. The labels are
  # the image module's, even though the disk is NVMe rather than SD.
  fileSystems = {
    "/" = {
      device = lib.mkDefault "/dev/disk/by-label/NIXOS_SD";
      fsType = lib.mkDefault "ext4";
    };
    "/boot/firmware" = {
      device = lib.mkDefault "/dev/disk/by-label/FIRMWARE";
      fsType = lib.mkDefault "vfat";
      # Automount, not plain noauto: see hosts/datapad -- with noauto the
      # bootloader installer silently wrote into the empty mountpoint.
      options = lib.mkDefault [
        "nofail"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=1min"
      ];
    };
  };

  # Nobody is on site to power-cycle it: reboot on a hung kernel.
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30s";
    RebootWatchdogSec = "5min";
  };

  services.fstrim.enable = true;
  services.journald.extraConfig = "SystemMaxUse=500M";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [ sshKey ];
  # No password: the box is headless and SSH is key-only.
  users.users.jdreier = {
    isNormalUser = true;
    description = "James Dreier";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ sshKey ];
  };
  security.sudo.wheelNeedsPassword = false;

  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  # Resolve .local names (printers, Chromecasts, Plex clients) with avahi-browse.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  # Per-interface traffic history, to answer "was the internet slow on Tuesday?".
  services.vnstat.enable = true;

  # Scraped from home over the tailnet (tailscale0 is trusted in network.nix).
  services.prometheus.exporters.node.enable = true;

  environment.systemPackages = with pkgs; [
    # Diagnostics
    arp-scan
    dnsutils
    ethtool
    iperf3
    mtr
    nmap
    speedtest-cli
    tcpdump
    wireshark-cli
    # Remote helpers
    wakeonlan
    raspberrypi-eeprom # rpi-eeprom-update / rpi-eeprom-config
    # Shell
    curl
    git
    htop
    tmux
  ];

  # Keep this at the release used for the initial installation.
  system.stateVersion = "26.05";
}
