{ pkgs, ... }:

let
  # This public host key was verified using the existing trusted LAN entry.
  studioHostKeys = pkgs.writeText "studio-known-hosts" ''
    holocron ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKXLOnYrejrfjt3t1dhk2+4aq+7JAL6sLDhYOsA/Lrq1
  '';
  studio = pkgs.writeShellApplication {
    name = "studio";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      session="''${1:-dev}"
      if [[ $# -gt 1 || ! "$session" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Usage: studio [session-name] (letters, digits, underscores, hyphens)" >&2
        exit 2
      fi
      exec ssh -t studio \
        "exec /bin/zsh -l -c 'cd /Users/jdreier/Projects && exec tmux new-session -A -s $session'"
    '';
  };
  studioDesktop = pkgs.writeShellApplication {
    name = "studio-desktop";
    runtimeInputs = [ pkgs.rustdesk-flutter ];
    text = ''
      exec rustdesk --connect 100.118.166.83:21118 "$@"
    '';
  };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."studio holocron holocron.chimera-mooneye.ts.net" = {
      HostName = "holocron.chimera-mooneye.ts.net";
      User = "jdreier";
      HostKeyAlias = "holocron";
      UserKnownHostsFile = [
        "~/.ssh/known_hosts"
        "${studioHostKeys}"
      ];
      StrictHostKeyChecking = "yes";
      ConnectTimeout = 10;
      ServerAliveInterval = 30;
      ServerAliveCountMax = 3;
      ControlMaster = "auto";
      ControlPath = "~/.ssh/control-%C";
      ControlPersist = "10m";
    };
  };

  home.packages = [
    studio
    studioDesktop
    pkgs.rustdesk-flutter
  ];

  # rustdesk-flutter ships its own menu entry, but studio-desktop is a bare
  # script, so the Studio session was reachable only from a terminal. Exec is
  # the store path rather than the bare name: the launcher then works whatever
  # the session PATH looks like. The icon comes from rustdesk-flutter.
  xdg.desktopEntries.studio-desktop = {
    name = "Studio Desktop";
    genericName = "Remote Desktop";
    comment = "RustDesk session on the Mac Studio over Tailscale";
    exec = "${studioDesktop}/bin/studio-desktop";
    icon = "rustdesk";
    terminal = false;
    categories = [
      "Network"
      "RemoteAccess"
    ];
    settings.Keywords = "rustdesk;remote;studio;mac;";
  };

  programs.zsh.shellAliases.studio-code = "code --remote ssh-remote+studio /Users/jdreier/Projects";
}
