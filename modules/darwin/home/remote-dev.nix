{ pkgs, lib, ... }:

let
  rustdesk = pkgs.callPackage ../rustdesk-package.nix { };
in
{
  home.packages = [ rustdesk ];
  # Merge connection settings into the mutable app config; identities and
  # passwords stay outside the Nix store and Git.
  home.activation.rustdeskSettings = lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ] ''
    ${(pkgs.python3.withPackages (p: [ p.tomlkit ]))}/bin/python3 ${./rustdesk-settings.py}
  '';
  launchd.agents.rustdesk = {
    enable = true;
    config = {
      # The store path, not /Applications: nothing copies bundles there any
      # more, so a /Applications path would break at login.
      ProgramArguments = [ "${rustdesk}/Applications/RustDesk.app/Contents/MacOS/RustDesk" ];
      RunAtLoad = true;
      KeepAlive = {
        SuccessfulExit = false;
      };
      ProcessType = "Interactive";
    };
  };
  # Claude Code keeps its login in the login keychain, which SSH sessions cannot
  # read, so over SSH it reports "Not logged in". A long-lived token from
  # `claude setup-token` stands in there; it lives outside the Nix store and
  # Git. GUI sessions keep the keychain login, whose scopes are wider.
  programs.zsh.initContent = ''
    if [[ -n "$SSH_CONNECTION" && -r ~/.config/claude-ssh/oauth-token ]]; then
      export CLAUDE_CODE_OAUTH_TOKEN="$(<~/.config/claude-ssh/oauth-token)"
    fi
  '';
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
