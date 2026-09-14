{ pkgs }:
let
  # Better grep / find replacements
  search = with pkgs; [
    ripgrep
    fd
  ];

  # Better coreutils replacements
  coreutils = with pkgs; [
    tree
    bat   # cat with syntax highlighting
    eza   # ls replacement
  ];

  # AI / LLM tools
  ai = with pkgs; [
    lmstudio
    claude-code
  ];

  # LSP servers for agent diagnostics
  lsp = with pkgs; [
    pyright
    typescript-language-server
  ];

  # Project scaffolding
  scaffolding = with pkgs; [
    cookiecutter
  ];

  # Language runtimes
  runtimes = with pkgs; [
    nodejs_24
  ];

  # Cloud provider CLIs
  cloud = with pkgs; [
    google-cloud-sdk
  ];

  # ~/.docker/config.json sets credsStore "osxkeychain". OrbStack used to
  # supply that helper; nixpkgs' docker client does not ship it.
  containers = with pkgs; [
    docker-credential-helpers
  ];

  # Kubernetes tooling
  kubernetes = with pkgs; [
    kubectl
    argocd
  ];
in
  search ++ coreutils ++ ai ++ lsp ++ scaffolding ++ runtimes ++ cloud ++ containers ++ kubernetes
