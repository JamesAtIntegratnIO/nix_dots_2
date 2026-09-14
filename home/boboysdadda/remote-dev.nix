{ pkgs, ... }:

let
  # This public host key was verified using the existing trusted LAN entry.
  studioHostKeys = pkgs.writeText "studio-known-hosts" ''
    mac-studio ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKXLOnYrejrfjt3t1dhk2+4aq+7JAL6sLDhYOsA/Lrq1
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
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."studio mac-studio mac-studio.chimera-mooneye.ts.net" = {
      HostName = "mac-studio.chimera-mooneye.ts.net";
      User = "jdreier";
      HostKeyAlias = "mac-studio";
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

  home.packages = [ studio ];
  programs.zsh.shellAliases.studio-code = "code --remote ssh-remote+studio /Users/jdreier/Projects";
}
