# Architecture

Big-picture view of how nix-darwin, Home Manager, local AI services, and the opencode agent stack fit together.

## Overview

```
flake.nix
    │
    ├─► nix-darwin (darwinConfigurations.mac-studio)
    │       │
    │       ├─ modules/darwin/configuration.nix   ← host settings, system packages
    │       ├─ modules/darwin/local-ai.nix         ← launchd user agents
    │       └─ home-manager integration
    │               │
    │               └─ modules/darwin/home/home.nix       ← user baseline config
    │                       │
    │                       ├─ modules/darwin/home/packages.nix        ← user packages
    │                       ├─ modules/darwin/home/opencode/default.nix ← opencode stack
    │                       └─ modules/darwin/home/hermes/default.nix  ← Hermes agent
    │
    └─ modules/darwin/overlays.nix (LM Studio and a2a-sdk overrides)
```

## The Four Layers

### 1. nix-darwin (System)

Rooted in `modules/darwin/configuration.nix`. This is the macOS system configuration layer.

**Responsibilities:**
- Host name, primary user, shell
- `environment.systemPackages`: system-wide binaries available to all users
- `launchd` user agents for persistent services
- Activation scripts (app bundle copies, directory creation)
- Nix settings (flakes, experimental features)

**Key file:** `modules/darwin/packages.nix` — defines package groups (vcs, editors, network, monitoring, utils, languages, ai) that are concatenated into a flat `all` list.

### 2. Home Manager (User)

Rooted in `modules/darwin/home/home.nix`. This manages the user environment: dotfiles, shell config, user-level packages, and session variables.

**Responsibilities:**
- Git user config, zsh aliases and shell completion
- User packages (ripgrep, bat, eza, LSP servers, etc.)
- Session environment variables (CQ_LOCAL_DB_PATH, OPENCODE_ENABLE_EXA)
- Delegation to child modules (opencode, hermes)

**Key file:** `modules/darwin/home/packages.nix` — user package groups (search, coreutils, ai, lsp, scaffolding).

### 3. Local AI Services

Defined in `modules/darwin/local-ai.nix`. These run as `launchd` user agents — not system services.

**Responsibilities:**
- Qdrant vector database (always enabled)
- Ollama inference server (disabled by default, toggle-enabled)
- Shared directory structure for data and logs under `~/Library/Application Support/local-ai/` and `~/Library/Logs/local-ai/`

**Activation:** A custom `system.activationScripts.localAiDirs` ensures directories exist and are user-owned before any service starts.

### 4. Opencode AI Agent Stack

Defined in `modules/darwin/home/opencode/default.nix`, built by `modules/darwin/opencode/default.nix`.

**Responsibilities:**
- Generate `opencode.json` config from declarative inputs
- Render agent `.md` files with frontmatter + body from Nix attrsets
- Wire MCP servers (CQ, Qdrant)
- Install skills from GitHub sources (CQ, Qdrant, Matt Pocock, OpenSpec)
- Generate OpenSpec commands and skills at build time

**Output:** A derivation whose `$out/` mirrors `~/.config/opencode/`:
```
$out/
├── opencode.json
├── agents/
│   ├── architect.md
│   ├── build.md
│   └── ... (10 agents)
├── skills/
│   ├── cq/SKILL.md
│   ├── qdrant-*/
│   ├── openspec-*/
│   └── mattpocock-*/
├── commands/
│   ├── cq-reflect.md
│   ├── cq-status.md
│   └── opsx-*.md
└── AGENTS.md
```

## Data Flow

```
flake.nix
    │
    ▼
nix-darwin lib.darwinSystem { modules = [...] }
    │
    ├─► configuration.nix evaluates packages.nix
    │       └─► environment.systemPackages = all packages
    │
    ├─► local-ai.nix defines launchd user agents
    │       └─► Activation: mkdir + chown local-ai dirs
    │
    └─► home-manager.extraSpecialArgs passed through
            │
            ▼
        home.nix imports opencode + hermes modules
            │
            ├─► opencode/default.nix
            │       │
            │       ├─ import models.nix          → { model, provider }
            │       ├─ import agent-defs/          → attrs of agent defs
            │       ├─ build mcpServers            → cq + qdrant MCP
            │       ├─ build skills                → fetchFromGitHub × 4
            │       ├─ build commands              → transformCqCommand × 2
            │       ├─ mkOpencodeEnv { ... }       → opencode-env derivation
            │       ├─ openspecExtractScript       → Node.js extraction
            │       ├─ openspecOpencodeAssets      → OpenSpec skills/commands
            │       └─ opencodeEnvWithOpenSpec     → merged final env
            │
            └─► home.file.".config/opencode" = source opencodeEnvWithOpenSpec
                    └─► ~/.config/opencode/ on disk
```

## Module System Details

### Special Arguments

| Arg | Passed by | Available in |
|---|---|---|
| `pkgs` | nix-darwin / home-manager | All modules |
| `hostname` | flake.nix | darwin modules only |
| `username` | flake.nix → home-manager.extraSpecialArgs | darwin + home modules |
| `inputs` | flake.nix | home modules (opencode, hermes) |

### Overlays

The overlay in `modules/darwin/overlays.nix` does two things via `nixpkgs.overlays`:
1. **`a2a-sdk`**: Strips a failing test file before build (FastAPI introspection bug on darwin)
2. **`lmstudio`**: Pins a specific version and fetches the DMG from `installers.lmstudio.ai`

### Activation Scripts

One custom activation script:

1. **`system.activationScripts.localAiDirs`** (defined in `local-ai.nix`):
   - Creates log and data directories under `~/Library/`
   - Chowns everything to the current user

## nix-darwin vs Home Manager Separation

| Concern | Layer | Why |
|---|---|---|
| System packages (go, neovim, qdrant) | nix-darwin | Installed to `environment.systemPackages`, available system-wide |
| User packages (ripgrep, bat, opencode) | Home Manager | Installed to `home.packages`, user-isolated |
| launchd agents | nix-darwin | launchd is a system daemon manager; user agents are configured here |
| Dotfiles (`.gitconfig`, `.zshrc`) | Home Manager | User-level dotfile management |
| opencode config generation | Home Manager | Written to `~/.config/opencode/` |
| Environment variables | Home Manager | `home.sessionVariables` for user shell |

The key principle: **nix-darwin owns the system, Home Manager owns the user**. Packages that are needed both system-wide and in the user profile (like `lmstudio`) may appear in both layers.

## The mkOpencodeEnv Abstraction

`modules/darwin/opencode/default.nix` exports `mkOpencodeEnv`, a **pure Nix function** with zero Home Manager dependencies. This is intentional:

```nix
# Pure usage — no home-manager imports
mkOpencodeEnv {
  models = import ./models.nix;
  agents = import ./agent-defs { lib; };
  mcpServers = { ... };
  skills = { ... };
  commands = { ... };
  agentsMd = "...";
  extraConfig = { ... };
}
```

Because it's pure, the same function can be composed in multiple contexts:
- **Home Manager**: `home.file.".config/opencode".source = mkOpencodeEnv { ... };`
- **Dev shell**: `shellHook = "ln -sfT ${mkOpencodeEnv { ... }} ~/.config/opencode";`
- **Flake packages**: `packages.${system}.opencode-env = mkOpencodeEnv { ... };`

The opencode-specific module (`modules/darwin/home/opencode/default.nix`) is the **concrete consumer** — it provides the actual models, agents, skills, and MCP servers that get passed into `mkOpencodeEnv`.

## GUI App Discovery

Spotlight does not reliably index the `/Applications/Nix Apps` folder that
nix-darwin populates, so Nix-installed apps were historically invisible to
`⌘ space`.

[`mac-app-util`](https://github.com/hraban/mac-app-util) is imported as a
darwin module in `hosts/mac-studio/default.nix`. On each switch it builds
trampoline `.app` wrappers under `/Applications/Nix Trampolines` for
everything in `environment.systemPackages`. Trampolines are real bundles
rather than symlinks, so Spotlight and Launchpad index them, and they keep
working across store path changes.

This replaced a hand-rolled activation script that `ditto`-copied LM Studio
into `/Applications`. That script used `mkForce`, which dropped nix-darwin's
own applications activation entirely — so no other packaged app reached
`/Applications/Nix Apps` at all, and RustDesk needed a second copy of the
same hack. Both are gone; RustDesk is now an ordinary `systemPackages` entry.
