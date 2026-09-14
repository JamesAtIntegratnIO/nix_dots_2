# Builds the opencode.json config attrset from caller-supplied inputs.
# Returns a plain Nix attrset — not a derivation.
# Consumers pass this to builtins.toJSON or pkgs.writeText.
#
# Arguments:
#   models      — attrset with { model, small_model, provider } (from your models.nix)
#   mcpServers  — attrset merged into the opencode.json `mcp` block
#   extraConfig — attrset merged last; can override any key including compaction
{ models, mcpServers ? {}, extraConfig ? {} }:
let
  hasSmallModel = builtins.hasAttr "small_model" models && models.small_model != null;
  smallModel = models.small_model or null;
in
assert (!hasSmallModel || builtins.isString smallModel);
  {
    "$schema"   = "https://opencode.ai/config.json";
    autoupdate  = false;
    model       = models.model;
    provider    = models.provider;

    # Sane defaults for local model usage: auto-compact when context is full and
    # prune old tool outputs so large thinking models don't overflow the window.
    compaction = {
      auto  = true;
      prune = true;
    };
  }
  // (if hasSmallModel then { small_model = smallModel; } else {})
  // (if mcpServers != {} then { mcp = mcpServers; } else {})
  // extraConfig
