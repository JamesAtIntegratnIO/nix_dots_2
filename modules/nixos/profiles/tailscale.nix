{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.services.tailscale;
  # Any flag that would turn Tailscale SSH on (`--ssh`, `--ssh=true`).
  sshOn = builtins.filter (f: lib.hasPrefix "--ssh" f && f != "--ssh=false") (
    cfg.extraUpFlags ++ cfg.extraSetFlags
  );
in
{
  services.tailscale = {
    enable = true;
    # Allow direct encrypted peer connections; this does not expose SSH
    # (a host that wants it opens port 22 on tailscale0 itself).
    openFirewall = true;
    # Same client on every host, from its own unstable input. The Pis are
    # built from nixos-raspberrypi's own nixpkgs, which lags behind.
    package = inputs.tailscale-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.tailscale;
    # Keep Tailscale SSH off: plain OpenSSH with keys is used instead. In Oct
    # 2026 unpatched Tailscale SSH flaws (port forwarding to root, socket
    # swaps) were published; `tailscale set` here undoes any manual `--ssh`.
    extraSetFlags = [ "--ssh=false" ];
  };

  assertions = [
    {
      assertion = sshOn == [ ];
      message = "Tailscale SSH stays off (see modules/nixos/profiles/tailscale.nix); remove ${toString sshOn}.";
    }
  ];
}
