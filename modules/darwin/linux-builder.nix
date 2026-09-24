# Standalone aarch64-linux build VM for the Apple Silicon Mac Studio.
#
# nix-darwin's own `nix.linux-builder` module can't be used here: it asserts
# `nix.enable`, which is false because this host runs Determinate Nix (the Nix
# daemon and /etc/nix/nix.conf are managed outside nix-darwin). So this module
# reproduces the two pieces nix-darwin *can* still own declaratively -- the
# launchd VM service and the SSH host alias -- and registers the builder through
# /etc/nix/machines, which Nix already reads by default (`builders =
# @/etc/nix/machines`). Determinate's nix.conf / nix.custom.conf are left alone.
#
# Lets `nix build .#pocketterm-sdimage` (and any other aarch64-linux build) run
# natively on the Studio instead of needing a separate Linux box.
{
  pkgs,
  ...
}:

let
  # Bumped resources over the defaults so building a full SD image has room.
  # Sized for heavy builds (e.g. compiling the Pi 5 kernel from source) while
  # leaving the 64GB / 16-core Studio comfortable headroom for macOS and its
  # background services. 8GB was too little and the guest OOM-crashed mid-kernel.
  linuxBuilder = pkgs.darwin.linux-builder.override {
    modules = [
      {
        virtualisation.cores = 10;
        virtualisation.darwin-builder = {
          memorySize = 24576; # MiB
          diskSize = 65536; # MiB
        };
      }
    ];
  };

  # Fixed host key baked into pkgs.darwin.linux-builder (base64 of the guest's
  # ssh-ed25519 host key), matching nix-darwin's own linux-builder module.
  publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQkorVXVFV2RWQ2Igcm9vdEBuaXhvcwo=";

  # <uri> <systems> <sshKey> <maxJobs> <speedFactor> <supportedFeatures> <mandatoryFeatures> <base64HostKey>
  machinesFile = pkgs.writeText "nix-machines" ''
    ssh-ng://builder@linux-builder aarch64-linux /etc/nix/builder_ed25519 10 1 kvm,benchmark,big-parallel - ${publicHostKey}
  '';

  workingDirectory = "/var/lib/linux-builder";
in
{
  # The build VM. Its create-builder script generates an SSH keypair on first
  # start and sudo-installs it to /etc/nix/builder_ed25519 (group nixbld); the
  # launchd daemon runs as root, so that sudo is non-interactive.
  launchd.daemons.linux-builder = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      WorkingDirectory = workingDirectory;
    };
    environment.NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    script = ''
      export TMPDIR=/run/org.nixos.linux-builder USE_TMPDIR=1
      rm -rf "$TMPDIR"
      mkdir -p "$TMPDIR"
      trap 'rm -rf "$TMPDIR"' EXIT
      ${linuxBuilder}/bin/create-builder
    '';
  };

  system.activationScripts.preActivation.text = ''
    mkdir -p ${workingDirectory}
  '';

  # How Nix reaches the VM (it listens on localhost:31022 with a fixed host key).
  environment.etc."ssh/ssh_config.d/100-linux-builder.conf".text = ''
    Host linux-builder
      User builder
      Hostname localhost
      HostKeyAlias linux-builder
      Port 31022
      IdentityFile /etc/nix/builder_ed25519
  '';

  # Registers the builder for distributed builds. Read by the Nix daemon (as
  # root), so it works even though jdreier is not a trusted user.
  environment.etc."nix/machines".source = machinesFile;
}
