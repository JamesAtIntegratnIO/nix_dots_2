{ pkgs, lib, ... }:

{
  home.packages = [ (pkgs.callPackage ../rustdesk-package.nix { }) ];
  # Merge connection settings into the mutable app config; identities and
  # passwords stay outside the Nix store and Git.
  home.activation.rustdeskSettings = lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ] ''
    ${(pkgs.python3.withPackages (p: [ p.tomlkit ]))}/bin/python3 ${./rustdesk-settings.py}
  '';
  launchd.agents.rustdesk = {
    enable = true;
    config = {
      ProgramArguments = [ "/Applications/RustDesk.app/Contents/MacOS/RustDesk" ];
      RunAtLoad = true;
      KeepAlive = {
        SuccessfulExit = false;
      };
      ProcessType = "Interactive";
    };
  };
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    escapeTime = 0;
    keyMode = "vi";
    mouse = true;
    prefix = "C-Space";
    extraConfig = ''
      set -g renumber-windows on
    '';
  };
}
