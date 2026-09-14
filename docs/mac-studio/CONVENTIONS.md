# Conventions

How to add packages, agents, services, and other changes — the "how to work here" guide.

## Package Groups

Both nix-darwin and Home Manager organize packages into named groups (lists) that are concatenated into a flat list.

### System Packages — `modules/darwin/packages.nix`

```nix
vcs = with pkgs; [ git gnupg ];
editors = with pkgs; [ neovim ];
network = with pkgs; [ wget curl ];
monitoring = with pkgs; [ htop ];
utils = with pkgs; [ jq ];
languages = with pkgs; [ go golangci-lint nixd uv ];
containers = with pkgs; [ docker docker-compose docker-buildx colima docker-sbx ];
ai = [ pkgs.lmstudio pkgs.ollama pkgs.qdrant ];

all = vcs ++ editors ++ network ++ monitoring ++ utils ++ languages ++ containers ++ ai;
```

The groups are roughly ordered by role. `all` is a left-to-right concatenation.

### User Packages — `modules/darwin/home/packages.nix`

```nix
search = with pkgs; [ ripgrep fd ];
coreutils = with pkgs; [ tree bat eza ];
ai = with pkgs; [ lmstudio ];
lsp = with pkgs; [ pyright typescript-language-server ];
scaffolding = with pkgs; [ cookiecutter ];
cloud = with pkgs; [ google-cloud-sdk ];

# Flattened: search ++ coreutils ++ ai ++ lsp ++ scaffolding ++ cloud
```

### How to Add a New Package

1. **System package** (available to all users, needed by services):
   - Edit `modules/darwin/packages.nix`
   - Add to the appropriate group (vcs, editors, network, monitoring, utils, languages, ai)
   - If it's a new category, create a new group and include it in `all`

2. **User package** (per-user tools):
   - Edit `modules/darwin/home/packages.nix`
   - Add to the appropriate group (search, coreutils, ai, lsp, scaffolding)
   - If it's a new category, create a new group and append it to the flattened list

3. **Rebuild**:
   ```bash
   darwin-rebuild switch --flake .#mac-studio
   ```

### Naming Conventions

- Group names are **lowercase, singular** when possible: `vcs`, `editors`, `utils`, `ai`
- Group names use **descriptive nouns**, not verbs
- Package entries use the `pkgs.<name>` form (e.g., `pkgs.lmstudio`)
- Comments above groups describe the category in a few words

## Module Structure

### Darwin Modules — `modules/darwin/`

| File | Purpose |
|---|---|
| `configuration.nix` | Host settings, system packages, activation scripts |
| `packages.nix` | System package groups |
| `local-ai.nix` | launchd user agents for local AI services |

**Rule**: Keep `configuration.nix` slim. Move complex concerns (services, AI) into separate files imported by it.

### Home Modules — `modules/darwin/home/`

| File | Purpose |
|---|---|
| `home.nix` | User baseline: git, zsh, env vars, imports child modules |
| `packages.nix` | User package groups |
| `opencode/default.nix` | Opencode stack (models, agents, MCP, skills) |
| `hermes/default.nix` | Hermes agent configuration |

**Rule**: `home.nix` uses `lib.mkMerge` to combine the baseline config with child modules. Each child module is self-contained and returns a Home Manager option set.

### Opencode Module — `modules/darwin/opencode/`

| File | Purpose |
|---|---|
| `default.nix` | `mkOpencodeEnv` — pure function, no home-manager dependency |
| `lib/config.nix` | Builds the opencode.json attrset |
| `lib/agents.nix` | Renders agent `.md` files with frontmatter |

## Toggle Pattern

Services are controlled by boolean flags:

```nix
let
  enableOllama = false;  # ← flip to true to enable
in {
  launchd.user.agents.ollama = lib.mkIf enableOllama {
    serviceConfig = { ... };
  };
}
```

**How it works:**
- The flag is a `let` binding at the top of the module
- `lib.mkIf enableOllama { ... }` only emits the service block when true
- The activation directories (logs, data) are always created regardless of toggle state, so enabling later doesn't require rebuilds to create dirs

**To enable a toggle service:**
1. Set the flag to `true`
2. Run `darwin-rebuild switch --flake .#mac-studio`
3. The service starts automatically via `RunAtLoad = true`

**To disable:** Set the flag back to `false` and rebuild. The service stops; data dirs remain.

## How to Add a New Agent

1. **Create the agent definition file:**
   ```bash
   echo '' > modules/darwin/home/opencode/agent-defs/my_agent.nix
   ```

2. **Write the definition** following the schema in `common.nix`:
   ```nix
   { common }:
   {
     description = "Brief one-line description of this agent.";
     mode = "subagent";  # or "primary"
     steps = 30;         # optional, not all agents need steps
     temperature = 0.2;
     permission = common.mkSubagentPermission "allow";  # or common.commonPermission // { ... }
     body = ''
   ## Identity
   
   You are the My Agent. Your goal is ...
   
   ## Responsibilities
   
   - ...
   
   ${common.projectRuleAwareness}
     '';
   }
   ```

3. **Register it** in `modules/darwin/home/opencode/agent-defs/default.nix`:
   ```nix
   my_agent = validateAgent "my_agent" (import ./my_agent.nix { inherit common; });
   ```

4. **Rebuild**:
   ```bash
   darwin-rebuild switch --flake .#mac-studio
   ```

**Agent fields reference:**

| Field | Required | Values | Notes |
|---|---|---|---|
| `description` | Yes | string | Shown in opencode agent list |
| `mode` | Yes | `"primary"` or `"subagent"` | Validated at build time |
| `temperature` | Yes | float | Model temperature |
| `permission` | Yes | permission attrset | See permission patterns below |
| `body` | Yes | string | Agent markdown (identity, responsibilities, constraints) |
| `steps` | No | int | Max reasoning steps (only on `build` and `project_lead`) |

**Permission patterns:**

- **Full access** (primary agents): `common.commonPermission // { bash = { "*"; "ask"; ... }; task = "allow"; }`
- **Subagent with broad bash**: `common.mkSubagentPermission "allow"`
- **Subagent with restricted bash**: `common.mkSubagentPermission "ask"`
- **Scoped edit** (docs-only agents): `common.mkSubagentPermission "deny" // { edit = common.mkScopedEditPermission [ "FILE.md" ]; }`

## How to Add a New Local AI Service

1. **Add the package** to `modules/darwin/packages.nix` in the `ai` group if needed.

2. **Add the service** to `modules/darwin/local-ai.nix`:
   - Set `enableMyService = false` as a toggle
   - Add the `launchd.user.agents` block with `lib.mkIf enableMyService`
   - Include `ProgramArguments`, `EnvironmentVariables`, `RunAtLoad`, `KeepAlive`
   - Set `StandardOutPath` and `StandardErrorPath` to `~/Library/Logs/local-ai/`
   - If it needs data dirs, add to the activation script block

3. **If it needs a config file**, add an `environment.etc."..."` entry.

4. **Rebuild** as above.

## How to Add a New Model

1. **Edit `modules/darwin/home/opencode/models.nix`**:
   ```nix
   {
     provider = "lmstudio";
     id = "my-new-model";
     title = "My New Model Display Name";
     role = "available";  # or "primary" or omit
   }
   ```

2. **If it's the primary model**, change the existing primary model's role to `"available"` and set the new one to `"primary"`. There must be exactly one of each role.

3. **Verify** the provider config in the `providers` attrset has the right `baseURL` and `apiKey`.

4. **Rebuild** to regenerate opencode.json.

## How to Add a New Skill

1. **Identify the source** — is it from GitHub, a local path, or a command transformation?

2. **For GitHub skills** (like Qdrant or Matt Pocock skills), use `pkgs.fetchFromGitHub`:
   ```nix
   mySkills = pkgs.fetchFromGitHub {
     owner = "...";
     repo = "...";
     rev = "...";
     hash = "sha256-...";
   };
   ```

3. **Add to the `skills` attrset** in `modules/darwin/home/opencode/default.nix`:
   ```nix
   skills = {
     "path/to/SKILL.md" = "${mySkills}/path/to/SKILL.md";
   };
   ```

   The key is a **relative path** under the skills output directory. The value is a **store path**.

4. **Rebuild**. Skills appear under `~/.config/opencode/skills/`.

## How to Add a New Command

1. **Pick the source file** — usually from a GitHub repo (like CQ's commands).

2. **If it needs transformation** (e.g., stripping `name:` frontmatter, injecting `agent:`), use `transformCqCommand`:
   ```nix
   commands = {
     "my-command" = transformCqCommand {
       file = "${cqSrc}/path/to/command.md";
       agent = "build";
     };
   };
   ```

3. **If no transformation is needed**, just reference the file directly:
   ```nix
   commands = {
     "my-command" = "${someSrc}/command.md";
   };
   ```

## How to Add a New MCP Server

1. **Add the MCP server definition** to the `mcpServers` attrset in `modules/darwin/home/opencode/default.nix`:
   ```nix
   mcpServers = {
     myMcp = {
       type = "local";
       enabled = true;
       command = [ "${pkgs.myMcpBinary}/bin/mcp-server" ];
       environment = {
         API_KEY = "your-key";
       };
     };
   };
   ```

2. **If it needs a Python venv**, follow the `qdrantMcpEnv` pattern:
   ```nix
   myMcpEnv = pkgs.runCommand "my-mcp-env" {
     nativeBuildInputs = [ pkgs.uv pkgs.cacert pkgs.python3 ];
   } ''
     export HOME="$TMPDIR"
     export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
     uv venv --python ${pkgs.python3}/bin/python3 "$out"
     uv pip install --python "$out/bin/python" --only-binary :all: my-mcp-package
   '';
   ```

3. **Add the env to `home.packages`** to keep it GC-rooted.

4. **Rebuild**.

## Herme Agent Configuration

The Hermes agent (`modules/darwin/home/hermes/default.nix`) is configured separately from opencode. It uses:

- **Config file:** `~/.hermes/config.yaml` — generated at build time
- **Credentials:** `~/.hermes/.env` — user must copy from `.env.example` and add real keys
- **Skills:** `~/.agents/mattpocock-skills/` — shared with opencode

To change Hermes config, edit `modules/darwin/home/hermes/default.nix`. The config uses `pkgs.formats.yaml`.

## Update Scripts

### LM Studio — `scripts/update-lmstudio.sh`

This script fetches the latest LM Studio version from `lmstudio.ai` and updates `modules/darwin/overlays.nix` automatically. It:
1. Fetches the redirect URL to extract the latest version string
2. Computes the new SHA-256 hash
3. Uses Perl to patch the version and hash in the LM Studio overlay

Run it whenever LM Studio releases a new version.

## Key Principles

1. **Packages go in groups** — never add to the flat list directly. Always add to a named group.
2. **Toggles are `let` bindings** — service flags use this pattern for easy enable/disable.
3. **mkOpencodeEnv is pure** — never import home-manager inside `modules/darwin/opencode/`.
4. **Agent validation is at build time** — missing fields or invalid modes fail evaluation immediately.
5. **All skills are pinned** — use specific git revs and sha256 hashes, never `main` branches.
6. **MCP venvs are GC-rooted** — always add them to `home.packages` so Nix won't garbage-collect them.
7. **Directories before services** — activation scripts create data dirs before any service references them.
