# OpenStack

The opencode AI agent configuration stack: models, agents, MCP servers, skills, and OpenSpec integration.

## Overview

```
models.nix + agent-defs/ + mcpServers + skills + commands
        ↓
  mkOpencodeEnv (modules/darwin/opencode/default.nix)
        ↓
  opencode-env (Nix derivation: opencode.json + agents/ + skills/ + commands/)
        ↓
  openspecOpencodeAssets overlay (OpenSpec commands + skills added on top)
        ↓
  home.file.".config/opencode"   ←  ~/.config/opencode/
```

The output directory structure on disk (`~/.config/opencode/`):

```
~/.config/opencode/
├── opencode.json
├── AGENTS.md
├── agents/
│   ├── architect.md
│   ├── build.md
│   ├── developer.md
│   ├── devops_engineer.md
│   ├── product_manager.md
│   ├── project_lead.md
│   ├── qa_engineer.md
│   ├── security_engineer.md
│   ├── technical_writer.md
│   └── ux_designer.md
├── skills/
│   ├── cq/SKILL.md
│   ├── qdrant-clients-sdk/
│   ├── qdrant-deployment-options/
│   ├── qdrant-hybrid-search/
│   ├── qdrant-model-migration/
│   ├── qdrant-monitoring/
│   ├── qdrant-performance-optimization/
│   ├── qdrant-scaling/
│   ├── qdrant-search-quality/
│   ├── qdrant-version-upgrade/
│   ├── mattpocock-engineering/
│   ├── mattpocock-misc/
│   ├── mattpocock-personal/
│   ├── mattpocock-productivity/
│   ├── openspec-apply-change/
│   ├── openspec-apply-tasks/
│   ├── openspec-explore/
│   ├── openspec-propose/
│   └── openspec-sync-specs/
├── commands/
│   ├── cq-reflect.md
│   ├── cq-status.md
│   ├── opsx-apply.md
│   ├── opsx-explore.md
│   ├── opsx-propose.md
│   └── opsx-sync.md
└── ... (generated)
```

## Models

Defined in `modules/darwin/home/opencode/models.nix`. Each model declares a provider, ID, display title, and role.

### Provider Configuration

| Provider | npm package | baseURL | apiKey |
|---|---|---|---|
| `lmstudio` | `@ai-sdk/openai-compatible` | `http://127.0.0.1:1234/v1` | `lmstudio` |

The provider config is consumed by opencode's AI SDK integration. The `baseURL` points to LM Studio's local OpenAI-compatible API.

### Model Roles

| Role | Effect |
|---|---|
| `"primary"` | Sets `model` in `opencode.json` — the default model used for all conversations |
| `"available"` | Visible in opencode's model selector but not a default |
| *(no role)* | Not assigned, effectively invisible |

There must be exactly one model with role `"primary"`. The Nix evaluation will throw if there are zero or multiple primary models.

### Current Models

| ID | Title | Provider | Role |
|---|---|---|---|
| `qwen3.6-35b` | Qwen3.6 35B A3B | lmstudio | **primary** |
| `qwen3-coder` | Qwen3 Coder Next 80B MLX 4bit | lmstudio | available |

### How to Add a Model

1. Open `modules/darwin/home/opencode/models.nix`
2. Add a new entry to the `models` list:
   ```nix
   {
     provider = "lmstudio";
     id = "my-new-model";
     title = "My New Model";
     role = "available";
   }
   ```
3. If making it the primary model, change the current primary's role to `"available"`.
4. Rebuild.

## Agents

10 agents defined across `modules/darwin/home/opencode/agent-defs/`. Each agent is a Nix file that returns an attribute set with `description`, `mode`, `temperature`, `permission`, and `body`.

### Agent Registry

| Agent | Mode | Temperature | Purpose |
|---|---|---|---|
| `project_lead` | primary | 0.1 | Plans, delegates, synthesizes. Never writes code. |
| `build` | primary | 0.2 | Default implementation agent. |
| `architect` | subagent | 0.1 | Design and architecture decisions. |
| `developer` | subagent | 0.2 | Feature implementation. |
| `qa_engineer` | subagent | 0.05 | Testing and quality certification. |
| `security_engineer` | subagent | 0.05 | Security review. |
| `technical_writer` | subagent | 0.2 | Documentation. |
| `devops_engineer` | subagent | 0.2 | Infrastructure and CI/CD. |
| `product_manager` | subagent | 0.1 | Requirements and user stories. |
| `ux_designer` | subagent | 0.35 | UX and accessibility. |

### Permission Order

The `permission` block in `opencode.json` always renders keys in this canonical order (defined in `modules/darwin/opencode/lib/agents.nix`):

```nix
permissionOrder = [
  "read" "edit" "glob" "grep" "list" "bash" "task" "skill"
  "question" "webfetch" "websearch" "external_directory" "doom_loop"
  "lsp"
];
```

This is the single source of truth for permission rendering order.

### Permission Patterns

| Pattern | Use Case | Bash Default |
|---|---|---|
| `common.commonPermission` | Full access for primary agents | `allow` for most ops |
| `common.mkSubagentPermission "allow"` | Subagent with broad bash access | `allow` |
| `common.mkSubagentPermission "ask"` | Subagent that must ask before bash | `ask` |
| `common.mkSubagentPermission "deny"` | Restricted subagent | `deny` |
| `common.mkScopedEditPermission [ "FILE.md" ]` | Edit only specific files | — |

Primary agents have custom bash permissions that allow specific commands without prompting (pwd, ls, find, rg, fd, cat, sed, awk, mkdir, cp, mv, go, git status/diff/add/log/branch).

### Adding a New Agent

1. Create `modules/darwin/home/opencode/agent-defs/<name>.nix`
2. Return an attrset with `description`, `mode`, `temperature`, `permission`, and `body`
3. Import it in `modules/darwin/home/opencode/agent-defs/default.nix` with `validateAgent`
4. Rebuild

Agent definitions are validated at Nix evaluation time — missing required fields or invalid `mode` values fail immediately.

### Agent Frontmatter

Each agent's `.md` file has YAML frontmatter rendered from the Nix definition:

```yaml
---
description: Build Agent
mode: primary
steps: 40
temperature: 0.2
permission:
  read: allow
  bash:
    "*": ask
    pwd: allow
    ...
---
<body content>
```

## MCP Servers

Two MCP servers configured in `modules/darwin/home/opencode/default.nix`:

### CQ (Knowledge Database)

| Property | Value |
|---|---|
| **Command** | `cq mcp` |
| **Binary** | Built from source via `modules/darwin/home/opencode/pkgs/cq.nix` |
| **Source** | `mozilla-ai/cq` rev `cli/v0.11.0` |
| **DB path** | `~/.local/share/cq/knowledge.db` |
| **Type** | `local` (stdio) |

CQ provides a shared SQLite-backed knowledge database. Agents can read/write knowledge units that persist across sessions. The `CQ_LOCAL_DB_PATH` environment variable is set in both `home.sessionVariables` and the MCP server config.

### Qdrant (Semantic Memory)

| Property | Value |
|---|---|
| **Command** | `mcp-server-qdrant` (from pre-built venv) |
| **Python env** | `qdrantMcpEnv` — built at Nix evaluation time |
| **QDRANT_URL** | `http://127.0.0.1:6333` |
| **COLLECTION_NAME** | `opencode-memory` |
| **EMBEDDING_MODEL** | `sentence-transformers/all-MiniLM-L6-v2` |
| **Type** | `local` (stdio) |

The Qdrant MCP server uses a pre-built Python venv (`qdrantMcpEnv`) to eliminate per-session PyPI downloads. The venv is pinned to nixpkgs Python and added to `home.packages` so the store path is GC-rooted and won't disappear between sessions.

**Key implementation detail:** The venv is built with `uv pip install --only-binary :all:` to avoid Rust compilation failures in the Nix sandbox (pydantic-core needs rustc). `HOME` is redirected to `$TMPDIR` because the sandbox uses a read-only `/homeless-shelter`. `UV_PYTHON_DOWNLOADS=never` forces uv to use nixpkgs Python, preventing symlinks to transitory build paths.

## Skills

Skills are installed to `~/.config/opencode/skills/` from four sources:

### Source 1: CQ

| Skill | Source |
|---|---|
| `cq/SKILL.md` | `mozilla-ai/cq` rev `cli/v0.11.0` |

### Source 2: Qdrant Skills Pack

| Skill | Description |
|---|---|
| `qdrant-clients-sdk` | Client SDKs for various languages |
| `qdrant-deployment-options` | Deployment selection guide |
| `qdrant-hybrid-search` | Hybrid search strategies |
| `qdrant-model-migration` | Embedding model migration |
| `qdrant-monitoring` | Monitoring and observability |
| `qdrant-performance-optimization` | Performance optimization techniques |
| `qdrant-scaling` | Scaling decisions guide |
| `qdrant-search-quality` | Search quality diagnosis |
| `qdrant-version-upgrade` | Version upgrade guidance |

Source: `qdrant/skills` rev `80f1980d126039c762664a3fe660bbad2eb1ec11` (pinned to commit SHA).

### Source 3: Matt Pocock Skills

| Skill pack | Contents |
|---|---|
| `mattpocock-engineering` | 33 SKILL.md files (tdd, diagnose-bugs, domain-modeling, implement, prototype, etc.) |
| `mattpocock-productivity` | grill-me, grill-with-docs, grilling, handoff, teach, writing-great-skills |
| `mattpocock-misc` | git-guardrails, migrate-to-shoehorn, scaffold-exercises, setup-pre-commit |
| `mattpocock-personal` | edit-article, obsidian-vault |

Source: `mattpocock/skills` rev `v1.0.1`. Packageable via `pkgs.callPackage modules/darwin/nix/mattpocock-skills/`.

### Source 4: OpenSpec (Generated)

Generated at build time from the `openspec` flake input via a Node.js extraction script. No network calls — templates are read from the installed package directly.

| Skill | Source |
|---|---|
| `openspec-apply-change` | From `@fission-ai/openspec` skill templates |
| `openspec-apply-tasks` | From `@fission-ai/openspec` skill templates |
| `openspec-explore` | From `@fission-ai/openspec` skill templates |
| `openspec-propose` | From `@fission-ai/openspec` skill templates |
| `openspec-sync-specs` | From `@fission-ai/openspec` skill templates |

### Skill Discovery

The `skills.paths` in `opencode.json` is explicitly set to `~/.config/opencode/skills` to make discovery deterministic:

```json
{
  "skills": {
    "paths": ["/Users/jdreier/.config/opencode/skills"]
  }
}
```

## Commands

Commands are MD files that appear in opencode's command palette. They are added to `~/.config/opencode/commands/`.

### CQ Commands

| Command | Source | Transformation |
|---|---|---|
| `cq-reflect` | `mozilla-ai/cq` → `plugins/cq/commands/reflect.md` | Strips `name:` frontmatter, injects `agent: build` |
| `cq-status` | `mozilla-ai/cq` → `plugins/cq/commands/status.md` | Strips `name:` frontmatter, injects `agent: build` |

### OpenSpec Commands

Generated at build time: `opsx-propose`, `opsx-explore`, `opsx-apply`, `opsx-sync`, `opsx-archive`.

## AGENTS.md

The global `AGENTS.md` file provides cross-cutting instructions to all agents. It's generated from the `agentsMd` string in `modules/darwin/home/opencode/default.nix`:

```
## CQ
Before starting any implementation task, load the `cq` skill and follow its Core Protocol.

## Qdrant Memory
Use the `qdrant` MCP server for semantic memory whenever context from prior tasks could help.

## OpenSpec
For non-trivial features or refactors, use OpenSpec to define scope and tasks before implementation.
```

This ensures every agent session starts with these three protocols active.

## opencode.json Structure

The generated `opencode.json` contains:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "autoupdate": false,
  "model": "lmstudio/qwen3.6-35b",
  "provider": "lmstudio",
  "small_model": null,
  "compaction": {
    "auto": true,
    "prune": true
  },
  "mcp": {
    "cq": { "type": "local", "enabled": true, "command": ["cq", "mcp"], ... },
    "qdrant": { "type": "local", "enabled": true, "command": ["mcp-server-qdrant"], ... }
  },
  "lsp": true,
  "skills": { "paths": ["/Users/jdreier/.config/opencode/skills"] }
}
```

The `compaction` settings are defaults: auto-compact when context is full, prune old tool outputs to prevent overflow.

## Build-Time Generation

Everything is generated at Nix build time:

1. **opencode.json** — built by `lib/config.nix` from models, MCP servers, and extra config
2. **agent .md files** — rendered by `lib/agents.nix` from agent definitions
3. **OpenSpec assets** — extracted by a Node.js script from the `openspec` flake package
4. **CQ/Qdrant/Matt Pocock skills** — fetched via `fetchFromGitHub` at evaluation time

No manual copy steps, no runtime network calls. The entire `~/.config/opencode/` directory is a Nix store derivation.

## Common Issues

### qdrant MCP ENOENT

If the qdrant MCP server shows `ENOENT: no such file or directory`, the Python venv was garbage-collected. Fix:
```bash
darwin-rebuild switch --flake .#mac-studio
```
The `qdrantMcpEnv` is in `home.packages` to prevent this. If it happens, the GC root was lost.

### Skills not appearing

Skills are indexed at opencode startup. After a rebuild:
1. Quit all opencode processes (`killall opencode` or quit from GUI)
2. Start a fresh session
3. Verify with: `opencode debug skill | rg qdrant-`

### Nix evaluation fails on new .nix files

Nix flakes only see Git-tracked files. After creating a new file:
```bash
git add <file>
darwin-rebuild switch --flake .#mac-studio
```
