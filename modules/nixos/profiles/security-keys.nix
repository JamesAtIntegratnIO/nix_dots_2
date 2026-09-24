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

  # fido2-token / fido2-cred for poking at the key from the terminal.
  environment.systemPackages = [ pkgs.libfido2 ];

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "jdreier" ];
  };
}
