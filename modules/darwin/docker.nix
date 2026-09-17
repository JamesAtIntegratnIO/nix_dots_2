{ pkgs, lib, username, ... }:
let
  logDir = "/Users/${username}/Library/Logs/colima";

  # VM sizing for the Linux guest that hosts the docker daemon.
  cpus = "12";
  memory = "32";
  disk = "100";
in
{
  # Keep the colima log directory writable for the launchd user agent.
  system.activationScripts.colimaDirs.text = ''
    /bin/mkdir -p "${logDir}"
    /usr/sbin/chown -R ${username}:staff "${logDir}"
  '';

  # Colima runs the Linux VM the docker daemon lives in — nixpkgs' docker on
  # darwin is client-only, so without this there is nothing to connect to.
  # `--foreground` keeps the process attached so launchd can supervise it
  # instead of the usual detached background VM.
  launchd.user.agents.colima = {
    serviceConfig = {
      Label = "org.nixos.colima";
      ProgramArguments = [
        "${pkgs.colima}/bin/colima" "start"
        "--foreground"
        "--cpu" cpus
        "--memory" memory
        "--disk" disk
        # amd64 containers run under Rosetta, not colima's qemu 7.0, which
        # crashes Go 1.26 binaries and Chromium. The workstation's runner builds
        # and smoke-tests specmarshal's amd64 images this way.
        "--vm-type" "vz"
        "--vz-rosetta"
      ];
      EnvironmentVariables = {
        HOME = "/Users/${username}";
        # colima shells out to limactl, which needs the system ssh.
        PATH = lib.concatStringsSep ":" [
          "/usr/bin"
          "/bin"
          "/usr/sbin"
          "/sbin"
        ];
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/colima.log";
      StandardErrorPath = "${logDir}/colima.err";
    };
  };
}
