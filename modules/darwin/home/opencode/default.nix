{ pkgs, username, lib, inputs, ... }:
let
  mkOpencodeEnv = (import ../../opencode { inherit pkgs lib; }).mkOpencodeEnv;
  openspec = inputs.openspec.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # cq source — skill files, commands, and MCP binary all come from the same pin.
  cqSrc = pkgs.fetchFromGitHub {
    owner = "mozilla-ai";
    repo  = "cq";
    rev   = "cli/v0.11.0";
    hash  = "sha256-2bv1FgrbJlb+lBFgJm8izDu6hQf8UwiJxdzua9Xoi8k=";
  };

  # Qdrant agent skills — 8 hub skills teaching agents when/why/how to use Qdrant.
  # Pinned to a specific commit SHA to prevent build breakage on upstream `main` changes.
  qdrantSkills = pkgs.fetchFromGitHub {
    owner = "qdrant";
    repo  = "skills";
    rev   = "80f1980d126039c762664a3fe660bbad2eb1ec11";
    hash  = "sha256-ZM7BC8uHPzAGwUa1niV7TEuUHUAgaJB8Eska9ufljSM=";
  };

  # Matt Pocock's engineering & productivity skills — 33 SKILL.md files across
  # engineering, productivity, misc, personal, and deprecated categories.
  mattpocockSkills = pkgs.callPackage ../../nix/mattpocock-skills {};

  # cq binary used by shell completion and cq MCP server.
  cq = pkgs.callPackage ./pkgs/cq.nix {};

  # Pre-built Python environment with mcp-server-qdrant installed via uv.
  # This eliminates per-session PyPI resolution latency and network dependency
  # for the qdrant MCP server. The venv is built at Nix evaluation time so the
  # package is cached in the store.
  # HOME is redirected because the Nix sandbox uses /homeless-shelter as HOME
  # which is read-only; uv needs to write its cache and Python downloads there.
  # SSL_CERT_FILE is set to the nixpkgs ca-cert bundle because the sandbox
  # defaults to /no-cert-file.crt which doesn't exist.
  # rustc/cargo are needed because mcp-server-qdrant depends on pydantic-core
  # which includes a Rust native extension that must be compiled.
  # --only-binary :all: ensures we use pre-built wheels to avoid compilation
  # failures in the sandbox (pydantic-core Rust builds are fragile on some platforms).
  # IMPORTANT: force uv to use nixpkgs Python.
  # If uv downloads its own interpreter during the build, the venv can end up
  # symlinked to /nix/var/nix/builds/... paths that disappear after build,
  # causing runtime ENOENT for opencode MCP process spawn.
  qdrantMcpEnv = pkgs.runCommand "qdrant-mcp-env" {
    nativeBuildInputs = [ pkgs.uv pkgs.cacert pkgs.python3 ];
  } ''
    export HOME="$TMPDIR"
    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    export UV_PYTHON_DOWNLOADS=never
    uv venv --python ${pkgs.python3}/bin/python3 "$out"
    uv pip install --python "$out/bin/python" --only-binary :all: mcp-server-qdrant
  '';

  # Strip the `name:` frontmatter field (opencode uses filename as the name)
  # and inject `agent: <name>` as the last frontmatter key.
  transformCqCommand = { file, agent }:
    pkgs.runCommand "cq-cmd-${builtins.baseNameOf file}" {
      nativeBuildInputs = [ pkgs.gawk ];
    } ''
      awk -v agent="${agent}" '
        BEGIN { fm=1 }
        NR==1 { print; next }
        fm && /^---$/ { print "agent: " agent; print; fm=0; next }
        fm && /^name:/ { next }
        { print }
      ' ${file} > $out
    '';

  opencodeEnv = mkOpencodeEnv {
    models     = import ./models.nix;
    agents     = import ./agent-defs { inherit lib; };

    extraConfig = {
      lsp = true;
      # Make skill discovery explicit so all Nix-managed skills (including
      # qdrant/*) are always scanned from the managed global directory.
      skills.paths = [ "/Users/${username}/.config/opencode/skills" ];
    };

    mcpServers = {
      cq = {
        type    = "local";
        enabled = true;
        command = [ "${cq}/bin/cq" "mcp" ];
        environment = {
          CQ_LOCAL_DB_PATH = "/Users/${username}/.local/share/cq/knowledge.db";
        };
      };
      # mcp-server-qdrant: semantic memory — store/retrieve information via Qdrant.
      # Uses a pre-built Python environment (qdrantMcpEnv) so the package is
      # resolved at build time, eliminating per-session PyPI latency.
      qdrant = {
        type    = "local";
        enabled = true;
        command = [ "${qdrantMcpEnv}/bin/mcp-server-qdrant" ];
        environment = {
          QDRANT_URL      = "http://127.0.0.1:6333";
          COLLECTION_NAME = "opencode-memory";
          EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2";
        };
      };
    };

    skills = {
      "cq/SKILL.md"                     = "${cqSrc}/plugins/cq/skills/cq/SKILL.md";
      "qdrant-clients-sdk"              = "${qdrantSkills}/skills/qdrant-clients-sdk";
      "qdrant-scaling"                  = "${qdrantSkills}/skills/qdrant-scaling";
      "qdrant-performance-optimization" = "${qdrantSkills}/skills/qdrant-performance-optimization";
      "qdrant-search-quality"           = "${qdrantSkills}/skills/qdrant-search-quality";
      "qdrant-monitoring"               = "${qdrantSkills}/skills/qdrant-monitoring";
      "qdrant-deployment-options"       = "${qdrantSkills}/skills/qdrant-deployment-options";
      "qdrant-model-migration"          = "${qdrantSkills}/skills/qdrant-model-migration";
      "qdrant-version-upgrade"          = "${qdrantSkills}/skills/qdrant-version-upgrade";
      # Matt Pocock skills — engineering, productivity, misc, personal
      "mattpocock-engineering"          = "${mattpocockSkills}/skills/engineering";
      "mattpocock-productivity"         = "${mattpocockSkills}/skills/productivity";
      "mattpocock-misc"                 = "${mattpocockSkills}/skills/misc";
      "mattpocock-personal"             = "${mattpocockSkills}/skills/personal";
    };

    commands = {
      "cq-reflect" = transformCqCommand {
        file  = "${cqSrc}/plugins/cq/commands/reflect.md";
        agent = "build";
      };
      "cq-status" = transformCqCommand {
        file  = "${cqSrc}/plugins/cq/commands/status.md";
        agent = "build";
      };
    };

    agentsMd = ''
      <!-- cq:start -->
      ## CQ

      Before starting any implementation task, load the `cq` skill and follow its Core Protocol.
      <!-- cq:end -->

      <!-- qdrant:start -->
      ## Qdrant Memory

      Use the `qdrant` MCP server for semantic memory whenever context from prior tasks could help.
      At task start, retrieve relevant memory from Qdrant.
      Before finishing, write concise implementation notes and decisions back to Qdrant.
      <!-- qdrant:end -->

      <!-- openspec:start -->
      ## OpenSpec

      For non-trivial features or refactors, use OpenSpec to define scope and tasks before implementation.
      Prefer: `openspec init` (once per repo), `/opsx:propose <change>`, `/opsx:apply`, and `/opsx:archive`.
      Keep implementation aligned to the active OpenSpec artifacts.
      <!-- openspec:end -->
    '';
  };

  # Generate OpenSpec OpenCode command and skill assets in a throwaway workspace
  # so they are managed declaratively by Nix and survive rebuilds.
  # Node.js script that extracts embedded skill/command templates from the
  # OpenSpec package without invoking the CLI (which makes a telemetry network
  # call that hangs inside the Nix sandbox).
  openspecExtractScript = pkgs.writeText "openspec-extract.mjs" ''
    import { getSkillTemplates, getCommandTemplates }
      from '${openspec}/lib/node_modules/@fission-ai/openspec/dist/core/shared/skill-generation.js';
    import { writeFileSync, mkdirSync } from 'fs';

    const out  = process.env.out;
    const core = ['propose', 'explore', 'apply', 'sync', 'archive'];

    for (const { dirName, template } of getSkillTemplates(core)) {
      const dir = out + '/skills/' + dirName;
      mkdirSync(dir, { recursive: true });
      const fm = '---\nname: ' + template.name
               + '\ndescription: "' + template.description + '"\n---\n\n';
      writeFileSync(dir + '/SKILL.md', fm + template.instructions + '\n');
    }

    for (const { id, template } of getCommandTemplates(core)) {
      writeFileSync(out + '/commands/opsx-' + id + '.md', template.content + '\n');
    }
  '';

  openspecOpencodeAssets = pkgs.runCommand "openspec-opencode-assets" {} ''
    mkdir -p "$out/commands" "$out/skills"
    ${pkgs.nodejs}/bin/node ${openspecExtractScript}
  '';

  # Overlay OpenSpec-generated assets on top of the base opencode environment.
  opencodeEnvWithOpenSpec = pkgs.runCommand "opencode-env-with-openspec" {} ''
    mkdir -p "$out"
    cp -rL ${opencodeEnv}/. "$out/"
    # Source trees in the Nix store can carry read-only modes; relax write bits
    # in the build output before overlaying generated OpenSpec assets.
    chmod -R u+w "$out"

    mkdir -p "$out/commands" "$out/skills"
    cp -rL ${openspecOpencodeAssets}/commands/. "$out/commands/"
    cp -rL ${openspecOpencodeAssets}/skills/. "$out/skills/"
  '';
in
{
  # Keep qdrantMcpEnv in the Home Manager profile so the interpreter path used
  # in opencode.json remains GC-rooted and cannot disappear between sessions.
  home.packages = [ pkgs.opencode cq openspec qdrantMcpEnv ];

  home.file.".config/opencode" = {
    source = opencodeEnvWithOpenSpec;
    recursive = true;
    force = true;
  };
}
