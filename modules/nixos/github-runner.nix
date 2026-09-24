{ pkgs, lib, ... }:
let
  runnerUser = "ghrunner";

  # Scope is fixed at registration and one instance takes one job at a time, so
  # a repository that wants this host needs an instance of its own here.
  #
  # specmarshal has eight rather than the darwin module's four. This host is
  # x86_64, so it takes the image matrix's amd64 leg natively instead of the
  # Mac's Rosetta emulation, and that leg fans out to five builds: four
  # instances leave the fifth queueing behind the others. Eight covers one
  # wave with room for a second pull request's, and matches the VM's eight
  # vCPU against its 24G of memory.
  specmarshalInstances = 8;

  instances = {
    runwright = "JamesAtIntegratnIO/runwright";
  } // builtins.listToAttrs (
    map
      (n: {
        name = if n == 1 then "specmarshal" else "specmarshal-${toString n}";
        value = "IntegratnIO/specmarshal";
      })
      (lib.range 1 specmarshalInstances)
  );

  # The registration token each instance consumes on first start. It expires
  # within the hour, but the module only needs it once: the credential it mints
  # lives in the instance's state directory afterwards. scripts/register-runner-nixos.sh
  # writes these.
  tokenDir = "/var/lib/github-runner-tokens";

  # Where each instance checks out and builds. The module's default is its
  # RuntimeDirectory under /run, a tmpfs capped at a quarter of RAM (5.9G here)
  # and shared by every instance; eight checkouts with their node_modules filled
  # it and jobs died with "No space left on device". This puts them on the disk.
  # HOME is the work dir too, so toolchain caches land here as well. Changing it
  # re-registers every instance: run scripts/register-runner-nixos.sh after.
  workRoot = "/var/lib/github-runner-work";

  runner = instance: repo: {
    name = instance;
    value = {
      enable = true;
      url = "https://github.com/${repo}";
      name = "ghrunner-${instance}";
      tokenFile = "${tokenDir}/${instance}";
      extraLabels = [ "nix" ];
      replace = true;
      workDir = "${workRoot}/${instance}";
      user = runnerUser;
      group = runnerUser;
      extraPackages = with pkgs; [
        docker
        docker-buildx
        nix
        gnutar
        gzip
        curl
      ];
      # One docker config per instance, so concurrent jobs don't share buildx
      # state or registry logins. See the darwin module for the failure this
      # avoids.
      extraEnvironment.DOCKER_CONFIG = "/var/lib/github-runner/${instance}/.docker";
    };
  };
in
{
  # Actions that provision a toolchain — actions/setup-node above all — download
  # a generic linux-x86_64 tarball and run it. Those binaries expect an
  # interpreter at /lib64/ld-linux-x86-64.so.2, which NixOS does not have, so
  # every such step dies with "Could not start dynamically linked executable".
  # nix-ld supplies the interpreter and the libraries the tarballs link against,
  # which keeps the workflows arch-agnostic: they run the same steps here as on
  # the Mac rather than branching on which host took the job.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      openssl
    ];
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  users.groups.${runnerUser} = { };
  users.users.${runnerUser} = {
    isSystemUser = true;
    group = runnerUser;
    extraGroups = [ "docker" ];
    description = "GitHub Actions self-hosted runner";
  };

  nix.settings.trusted-users = [ runnerUser ];

  systemd.tmpfiles.rules = [
    "d ${tokenDir} 0700 root root -"
  ]
  ++ map (instance: "d ${workRoot}/${instance} 0750 ${runnerUser} ${runnerUser} -") (
    builtins.attrNames instances
  );

  services.github-runners = lib.mapAttrs' runner instances;
}
