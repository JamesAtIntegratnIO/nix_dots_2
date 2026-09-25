# Waveshare PocketTerm35 handheld: Raspberry Pi 5 (16GB) with a 3.5" 640x480
# touchscreen, built-in QWERTY keyboard, and gaming buttons.
#
# Built and deployed from the aarch64 Mac Studio (native, no emulation). The
# first install is flashed from `nixosConfigurations.pocketterm-sdimage`; after
# that, deploy with `nixos-rebuild switch --flake .#pocketterm --target-host`.
{
  lib,
  ...
}:

let
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIESq1wdY7diOloASvawJgjjThP6kzDWC/J3NIzZu5QVe james@integratn.io";
in
{
  imports = [
    ../../modules/nixos/core/locale.nix
    ../../modules/nixos/core/nix.nix
    ../../modules/nixos/profiles/tailscale.nix
    ../../modules/nixos/profiles/pocketterm-hardware.nix
    ../../modules/nixos/profiles/wayland-kiosk.nix
    ../../modules/nixos/profiles/cyberdeck
    ../../modules/nixos/profiles/screen-dim
    ../../modules/nixos/profiles/pentest.nix
    ../../modules/nixos/profiles/security-keys.nix
    ../../modules/nixos/profiles/power.nix
    ../../modules/nixos/profiles/emulation.nix
  ];

  networking.hostName = "pocketterm";
  networking.networkmanager.enable = true;

  # Matches the layout written by `.#pocketterm-sdimage`. Declared here so the
  # deployable config (target-host rebuilds) is valid too; mkDefault lets the
  # sd-image module own these definitions while building the image itself.
  fileSystems = {
    "/" = {
      device = lib.mkDefault "/dev/disk/by-label/NIXOS_SD";
      fsType = lib.mkDefault "ext4";
    };
    "/boot/firmware" = {
      device = lib.mkDefault "/dev/disk/by-label/FIRMWARE";
      fsType = lib.mkDefault "vfat";
      # Automount, not plain noauto: the bootloader installer writes kernels,
      # initrds and cmdline.txt here on every switch. With noauto it silently
      # wrote into the empty mountpoint on the root fs, leaving the real
      # partition booting a stale generation.
      options = lib.mkDefault [
        "nofail"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=1min"
      ];
    };
  };

  # PipeWire for the built-in stereo speaker / 3.5mm jack.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [ sshKey ];
  users.users.jdreier = {
    isNormalUser = true;
    description = "James Dreier";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video" # GPU / DRM access
      "audio"
      "input"
      "dialout" # serial consoles (/dev/ttyUSB*, /dev/ttyACM*)
      "i2c"
      "gpio"
    ];
    openssh.authorizedKeys.keys = [ sshKey ];
    # Set a real password with `passwd` after first boot so the device is
    # usable standalone; key-only SSH is enforced above regardless.
    initialPassword = "changeme";
  };
  security.sudo.wheelNeedsPassword = false;

  # Lets `nixos-rebuild --target-host` push closures built on the Mac Studio.
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  # Keep this at the release used for the initial installation.
  system.stateVersion = "26.05";
}
