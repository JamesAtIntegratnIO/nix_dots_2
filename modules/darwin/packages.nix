{ pkgs }:
let
  # Version control & security
  vcs = with pkgs; [
    git
    gnupg
  ];

  # Editors
  editors = with pkgs; [
    neovim
  ];

  # Network & download utilities
  network = with pkgs; [
    wget
    curl
  ];

  # System monitoring
  monitoring = with pkgs; [
    htop
  ];

  # Data & scripting utilities
  utils = with pkgs; [
    jq
  ];

  # Languages & runtimes
  languages = with pkgs; [
    go
    golangci-lint
    nixd   # Nix language server for LSP diagnostics
    uv     # Python package runner — needed for uvx mcp-server-qdrant
  ];

  # Containers — docker CLI plus colima, which runs the Linux VM the
  # daemon needs (nixpkgs' docker on darwin ships the client only).
  #
  # docker-sbx provides `sbx`, the standalone form of `docker sandbox` for
  # running coding agents in disposable microVMs. It manages its own VMs and
  # does not talk to the colima daemon.
  containers = with pkgs; [
    docker
    docker-compose
    docker-buildx
    colima
    docker-sbx
  ];

  # Local AI stack
  ai = [
    pkgs.lmstudio
    pkgs.ollama
    pkgs.qdrant
  ];
in {
  # Flat list for environment.systemPackages.
  all = vcs ++ editors ++ network ++ monitoring ++ utils ++ languages ++ containers ++ ai;
}
