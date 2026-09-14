{ pkgs, username, lib, inputs, ... }:
let
  homePackages = import ./packages.nix { inherit pkgs; };
  opencodeModule = import ./opencode/default.nix { inherit pkgs username lib inputs; };
  hermesModule = import ./hermes/default.nix { inherit pkgs username lib inputs; };
  remoteDevModule = import ./remote-dev.nix { inherit pkgs lib; };
in
lib.mkMerge [
  {
    home.username = username;
    home.homeDirectory = "/Users/${username}";

    # Keep this at the Home Manager version you started with.
    home.stateVersion = "24.11";

    programs.home-manager.enable = true;

    home.packages = homePackages;

    # Docker CLI plugins — the docker client only discovers subcommands like
    # `docker compose` from ~/.docker/cli-plugins, not from $PATH.
    # `force` because other docker installs drop their own links here; scoped
    # to these two paths rather than a global backupFileExtension, which would
    # make activation try to back up targets that resolve into the Nix store.
    home.file.".docker/cli-plugins/docker-compose" = {
      force = true;
      source = "${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose";
    };
    home.file.".docker/cli-plugins/docker-buildx" = {
      force = true;
      source = "${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx";
    };

    programs.git = {
      enable = true;
      settings = {
        user.name = "James Dreier";
        user.email = "james@integratn.io";
      };
    };

    programs.zsh = {
      enable = true;
      shellAliases = {
        ll = "eza -la";
        ls = "eza";
        grep = "rg";
      };
      # cq shell completion
      initContent = ''
        source <(cq completion zsh)
      '';
    };

    # Extra directories appended to PATH. nix-darwin's generated /etc/zprofile
    # does not run macOS's path_helper, so /etc/paths.d entries (notably
    # Homebrew's) never reach PATH on their own.
    home.sessionPath = [ "$HOME/.local/bin" "$HOME/go/bin" "/opt/homebrew/bin" ];
    # Environment variables for opencode integrations.
    home.sessionVariables = {
      # Path to the cq knowledge database — shared with the cq MCP server config.
      CQ_LOCAL_DB_PATH = "/Users/${username}/.local/share/cq/knowledge.db";
      # Enable Exa web search integration in opencode. Set to "" or remove to disable.
      OPENCODE_ENABLE_EXA = "1";
    };
  }

  opencodeModule
  hermesModule
  remoteDevModule
]
