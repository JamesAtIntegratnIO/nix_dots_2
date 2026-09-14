{ lib }:
let
  common = import ./common.nix {};

  # Validate that an agent definition has all required fields.
  # Fails at Nix evaluation time if any required field is missing or
  # if mode is not one of the allowed values.
  validateAgent = name: def:
    assert lib.assertMsg (builtins.hasAttr "description" def)
      "${name}: missing required field 'description'";
    assert lib.assertMsg (builtins.hasAttr "mode" def)
      "${name}: missing required field 'mode'";
    assert lib.assertMsg (builtins.hasAttr "temperature" def)
      "${name}: missing required field 'temperature'";
    assert lib.assertMsg (builtins.hasAttr "permission" def)
      "${name}: missing required field 'permission'";
    assert lib.assertMsg (builtins.hasAttr "body" def)
      "${name}: missing required field 'body'";
    assert lib.assertMsg (def.mode == "primary" || def.mode == "subagent")
      "${name}: mode must be 'primary' or 'subagent', got '${def.mode}'";
    def;
in
{
  build           = validateAgent "build"           (import ./build.nix           { inherit common; });
  project_lead    = validateAgent "project_lead"    (import ./project_lead.nix    { inherit common; });
  architect       = validateAgent "architect"       (import ./architect.nix       { inherit common; });
  developer       = validateAgent "developer"       (import ./developer.nix       { inherit common; });
  devops_engineer = validateAgent "devops_engineer" (import ./devops_engineer.nix { inherit common; });
  product_manager = validateAgent "product_manager" (import ./product_manager.nix { inherit common; });
  qa_engineer     = validateAgent "qa_engineer"     (import ./qa_engineer.nix     { inherit common; });
  security_engineer = validateAgent "security_engineer" (import ./security_engineer.nix { inherit common; });
  technical_writer = validateAgent "technical_writer" (import ./technical_writer.nix { inherit common; });
  ux_designer     = validateAgent "ux_designer"     (import ./ux_designer.nix     { inherit common; });
}