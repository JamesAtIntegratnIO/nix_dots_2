# Element, the Matrix client, for hosts with a desktop session.
{ pkgs, ... }:

let
  # Electron picks its secret store from XDG_CURRENT_DESKTOP and doesn't know
  # "sway", so it falls back to plaintext and Element refuses to start its
  # encrypted store ("unsupported keyring"). Point it at the Secret Service
  # (gnome-keyring) explicitly.
  element = pkgs.symlinkJoin {
    name = "element-desktop-libsecret";
    paths = [ pkgs.element-desktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/element-desktop \
        --add-flags "--password-store=gnome-libsecret"
    '';
  };
in
{
  environment.systemPackages = [ element ];

  # The Secret Service Element stores its keys in. Cinnamon already turns
  # this on.
  services.gnome.gnome-keyring.enable = true;

  # Run Electron apps as native Wayland clients under Sway instead of through
  # XWayland. Harmless on X11 sessions: the hint falls back to X11 there.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
