{ pkgs, lib, username, ... }:
let
  runnerUser = "ghrunner";
  runnerHome = "/Users/${runnerUser}";

  # Each registered runner instance, as a directory under
  # ${runnerHome}/actions-runner. A runner's scope is fixed when it is
  # registered and no workflow can widen it, so a repository that wants this
  # workstation needs an instance of its own here. Registration itself stays
  # manual, because it mints a credential; this only supervises what exists.
  #
  # specmarshal has four, because an instance takes one job at a time and its
  # image matrix fans out to five arm64 builds. On one instance those queue
  # behind each other and the run takes longer in wall clock than it did on
  # hosted runners, even though it now costs nothing.
  instances = [
    "runwright"
    "specmarshal"
    "specmarshal-2"
    "specmarshal-3"
    "specmarshal-4"
  ];

  # colima publishes the docker socket into the owning user's home as 0600 and
  # recreates it on every start, so it cannot simply be chmod'd once. socat
  # relays it instead: root can open colima's socket, and the copy it publishes
  # is owned by the runner account alone.
  colimaSocket = "/Users/${username}/.colima/default/docker.sock";
  runnerSocket = "/var/run/docker-${runnerUser}.sock";

  # What a job on this runner gets on PATH. /run/current-system/sw/bin carries
  # the docker CLI — nixpkgs' docker on darwin is client-only, which is what
  # colima's daemon is for — and the nix profile carries nix itself, which a
  # project whose gate runs in a dev shell needs.
  runnerPath = lib.concatStringsSep ":" [
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/opt/homebrew/bin"
    "${runnerHome}/.local/bin"
    "${runnerHome}/go/bin"
  ];

  # nix-darwin names a plist after its Label, so these adopt the
  # /Library/LaunchDaemons files the instances were first installed with by
  # hand rather than running a second copy of each alongside them.
  runnerDaemon = instance:
    let dir = "${runnerHome}/actions-runner/${instance}";
    in {
      name = instance;
      value.serviceConfig = {
        Label = "io.integratn.${runnerUser}.${instance}";
        UserName = runnerUser;
        WorkingDirectory = dir;
        ProgramArguments = [ "${dir}/bin/runsvc.sh" ];
        KeepAlive = true;
        RunAtLoad = true;
        SessionCreate = true;
        ProcessType = "Standard";
        StandardOutPath = "${dir}/_diag/daemon.out.log";
        StandardErrorPath = "${dir}/_diag/daemon.err.log";
        EnvironmentVariables = {
          PATH = runnerPath;
          HOME = runnerHome;
          DOCKER_HOST = "unix://${runnerSocket}";
          # Every instance runs as the same account, so they would otherwise
          # share one ~/.docker: a single buildx state directory and a single
          # config.json holding the registry login. Concurrent jobs then create
          # and remove builders in each other's state, which surfaces as a build
          # that completes every layer and then loses its builder while loading
          # the image. One config directory per instance keeps them apart.
          DOCKER_CONFIG = "${dir}/.docker";
        };
      };
    };
in
{
  # The account the runners run as: no shell and no password, because nothing
  # ever logs into it. It predates this module, so uid and gid restate what it
  # was created with rather than choosing anything.
  users.knownUsers = [ runnerUser ];
  users.users.${runnerUser} = {
    uid = 502;
    gid = 20;
    home = runnerHome;
    shell = "/usr/bin/false";
    ignoreShellProgramCheck = true;
    isHidden = true;
    description = "GitHub Actions self-hosted runner";
  };

  launchd.daemons = {
    # unlink-early clears a socket left behind by an unclean stop. KeepAlive
    # covers the ordering: this starts before colima's user agent has a socket
    # to connect to, and simply retries until it does.
    #
    # It is a `command`, not ProgramArguments, so nix-darwin wraps it in
    # `/bin/wait4path /nix/store`. At boot launchd starts system daemons before
    # the Nix volume is mounted; given socat's store path directly it logged
    # "Missing executable detected", marked the job inactive (exit 78,
    # EX_CONFIG) and never retried it — KeepAlive does not cover a job launchd
    # thinks has no program. The runners then had no docker socket until someone
    # booted the job out and back in. The runner daemons below need no such
    # guard: their program lives in the runner's home, not the store.
    docker-runner-socket = {
      command = lib.escapeShellArgs [
        "${pkgs.socat}/bin/socat"
        "UNIX-LISTEN:${runnerSocket},fork,unlink-early,user=${runnerUser},group=staff,mode=0600"
        "UNIX-CONNECT:${colimaSocket}"
      ];
      serviceConfig = {
        Label = "io.integratn.${runnerUser}.docker-socket";
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Background";
        StandardOutPath = "/var/log/docker-${runnerUser}-socket.log";
        StandardErrorPath = "/var/log/docker-${runnerUser}-socket.err";
      };
    };
  } // builtins.listToAttrs (map runnerDaemon instances);
}
