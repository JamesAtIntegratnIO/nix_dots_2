# mkOpencodeEnv — pure Nix function that builds the opencode config directory.
#
# No home-manager dependency. The returned derivation's $out/ mirrors the
# opencode config dir layout and can be wired up however the consumer needs:
#
#   HM:       home.file.".config/opencode".source = mkOpencodeEnv { ... };
#   devshell: shellHook = "ln -sfT ${mkOpencodeEnv { ... }} ~/.config/opencode";
#   flake:    packages.${system}.opencode-env = mkOpencodeEnv { ... };
#
# All content (models, agents, mcp servers, skills, commands) is supplied by
# the caller. This module defines no opinions about what models or agents to use.
#
# Parameter types (lib.types notation for documentation):
#   models      :: lib.types.attrs       — { model, small_model, provider }
#   agents      :: lib.types.attrsOf lib.types.attrs (default: {})
#   mcpServers  :: lib.types.attrsOf lib.types.attrs (default: {})
#   skills      :: lib.types.attrsOf (lib.types.path) (default: {})
#   commands    :: lib.types.attrsOf lib.types.path (default: {})
#   agentsMd    :: lib.types.str (default: "")
#   extraConfig :: lib.types.attrs (default: {})
{ pkgs, lib }:
{
  mkOpencodeEnv =
    { models              # required — { model, small_model, provider }
    , agents      ? {}    # attrset: name → agentDef
    , mcpServers  ? {}    # attrset: merged into opencode.json `mcp` block
    , skills      ? {}    # attrset: relative-path → store-path (file or dir)
    , commands    ? {}    # attrset: name → store-path (.md file, already rendered)
    , agentsMd    ? ""    # string: AGENTS.md body; file is omitted when ""
    , extraConfig ? {}    # attrset: merged last into opencode.json
    }:
    assert lib.assertMsg (builtins.isAttrs models) "models must be an attrset";
    assert lib.assertMsg (builtins.isAttrs agents) "agents must be an attrset";
    assert lib.assertMsg (builtins.isAttrs mcpServers) "mcpServers must be an attrset";
    assert lib.assertMsg (builtins.isAttrs skills) "skills must be an attrset";
    assert lib.assertMsg (builtins.isAttrs commands) "commands must be an attrset";
    assert lib.assertMsg (builtins.isString agentsMd) "agentsMd must be a string";
    assert lib.assertMsg (builtins.isAttrs extraConfig) "extraConfig must be an attrset";
    let
      buildConfig = import ./lib/config.nix;
      buildAgents = import ./lib/agents.nix;

      configJson = pkgs.writeText "opencode.json"
        (builtins.toJSON (buildConfig { inherit models mcpServers extraConfig; }));

      agentsDrv = buildAgents { inherit pkgs lib agents; };

      # Build bash snippets for skills and commands installation.
      skillsScript = lib.concatStringsSep "\n"
        (lib.mapAttrsToList (relPath: src: ''
          mkdir -p "$(dirname "$out/skills/${relPath}")"
          cp -rL ${src} "$out/skills/${relPath}"
        '') skills);

      commandsScript = lib.concatStringsSep "\n"
        (lib.mapAttrsToList (name: src: ''
          cp ${src} "$out/commands/${name}.md"
        '') commands);
    in
    pkgs.runCommand "opencode-env" {} ''
      mkdir -p "$out"

      # opencode.json
      cp ${configJson} "$out/opencode.json"

      # Agent markdown files
      ${lib.optionalString (agents != {}) ''
        mkdir -p "$out/agents"
        for f in ${agentsDrv}/*.md; do
          cp "$f" "$out/agents/"
        done
      ''}

      # Skills (files or directories keyed by path relative to skills/)
      ${lib.optionalString (skills != {}) skillsScript}

      # Command markdown files
      ${lib.optionalString (commands != {}) ''
        mkdir -p "$out/commands"
        ${commandsScript}
      ''}

      # AGENTS.md global context file
      ${lib.optionalString (agentsMd != "") ''
        cp ${pkgs.writeText "AGENTS.md" agentsMd} "$out/AGENTS.md"
      ''}
    '';
}
