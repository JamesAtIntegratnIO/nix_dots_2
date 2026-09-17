{ pkgs, lib, ... }:
let
  runnerUser = "ghrunner";

  # Same instances as modules/darwin/github-runner.nix, for the same reasons:
  # scope is fixed at registration, and one instance takes one job at a time.
  # Each maps to the repository it registers against.
  instances = {
    runwright = "JamesAtIntegratnIO/runwright";
    specmarshal = "IntegratnIO/specmarshal";
    specmarshal-2 = "IntegratnIO/specmarshal";
    specmarshal-3 = "IntegratnIO/specmarshal";
    specmarshal-4 = "IntegratnIO/specmarshal";
  };

  # The registration token each instance consumes on first start. It expires
  # within the hour, but the module only needs it once: the credential it mints
  # lives in the instance's state directory afterwards. scripts/register-runner-nixos.sh
  # writes these.
  tokenDir = "/var/lib/github-runner-tokens";

  runner = instance: repo: {
    name = instance;
    value = {
      enable = true;
      url = "https://github.com/${repo}";
      name = "ghrunner-${instance}";
      tokenFile = "${tokenDir}/${instance}";
      extraLabels = [ "nix" ];
      replace = true;
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

  systemd.tmpfiles.rules = [ "d ${tokenDir} 0700 root root -" ];

  services.github-runners = lib.mapAttrs' runner instances;
}
