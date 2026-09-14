# Renders a caller-supplied attrset of agent definitions to a directory derivation.
#
# Arguments:
#   pkgs    — nixpkgs
#   lib     — nixpkgs lib
#   agents  — attrset of name → agentDef
#
# Returns: derivation whose $out/ contains <name>.md for each agent.
{ pkgs, lib, agents }:
let
  # Canonical key order for the permission: block in agent frontmatter.
  # This is the single source of truth for permission rendering order.
  permissionOrder = [
    "read" "edit" "glob" "grep" "list" "bash" "task" "skill"
    "question" "webfetch" "websearch" "external_directory" "doom_loop"
    "lsp"
  ];

  renderPermissionEntry = permission: key:
    let value = permission.${key}; in
    if builtins.isAttrs value then
      let
        bashKeys  = builtins.attrNames value;
        bashLines = map (bk: "    ${builtins.toJSON bk}: ${value.${bk}}") bashKeys;
      in
      "  ${key}:\n${lib.concatStringsSep "\n" bashLines}"
    else
      "  ${key}: ${value}";

  renderFrontMatter = def:
    let
      keys           = builtins.filter (k: builtins.hasAttr k def.permission) permissionOrder;
      permissionLines = map (k: renderPermissionEntry def.permission k) keys;
      stepsLine      = lib.optionalString (builtins.hasAttr "steps" def)
                         "steps: ${toString def.steps}\n";
    in
    ''
      ---
      description: ${def.description}
      mode: ${def.mode}
      ${stepsLine}temperature: ${toString def.temperature}
      permission:
      ${lib.concatStringsSep "\n" permissionLines}
      ---

    '';

  # Each agent becomes a single store-path file via pkgs.writeText.
  renderAgent = name: def:
    pkgs.writeText "opencode-agent-${name}.md" (renderFrontMatter def + def.body);

  agentPaths = lib.mapAttrsToList (name: def: {
    inherit name;
    drv = renderAgent name def;
  }) agents;
in
pkgs.runCommand "opencode-agents" {} (
  lib.concatStringsSep "\n" (
    [ ''mkdir -p "$out"'' ]
    ++ map ({ name, drv }: ''cp ${drv} "$out/${name}.md"'') agentPaths
  )
)
