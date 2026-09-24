# Security keys + password manager for the handheld:
# - YubiKey / FIDO2 udev rules so the logged-in seat session can reach the key's
#   hidraw node (uaccess). Without these, browsers get only partial WebAuthn /
#   passkey support because they can't fully drive the device.
# - 1Password desktop + CLI, with the polkit policy / groups NixOS requires for
#   system auth, the SSH agent, and browser integration.
{
  pkgs,
  ...
}:

{
  services.udev.packages = [ pkgs.yubikey-personalization ];

  # Grant the active seat user direct access to the YubiKey's hidraw node
  # (uaccess). The personalization rules above only tag the USB device, not the
  # hidraw child the FIDO/CTAP2 stack talks to, so browsers only got partial
  # passkey support. Vendor 1050 = Yubico; covers every YubiKey FIDO interface.
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", TAG+="uaccess", MODE="0660"
  '';

  # fido2-token / fido2-cred for poking at the key from the terminal.
  environment.systemPackages = [ pkgs.libfido2 ];

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "jdreier" ];
    # 1Password's Electron window is larger than the 640x480 panel. Render it at
    # a smaller device-scale-factor so the whole UI fits, and run native Wayland.
    # overrideAttrs keeps the package's `.override` that this module calls.
    package = pkgs._1password-gui.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        wrapProgram $out/bin/1password \
          --add-flags "--ozone-platform-hint=auto --force-device-scale-factor=0.6"
      '';
    });
  };

  # Prefer the Wayland backend for Electron/Chromium apps generally.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
