let
  providers = {
    # LM Studio local server — load Qwen3-Coder-Next-MLX-4bit in the LM Studio UI first.
    lmstudio = {
      npm = "@ai-sdk/openai-compatible";
      name = "LM Studio (local)";
      options = {
        baseURL = "http://127.0.0.1:1234/v1";
        apiKey = "lmstudio";
      };
    };
  };

  # Single source of truth: define each model once.
  # role = "primary" sets model; role = "available" keeps a model selectable
  # without assigning it as a default.
  models = [
    {
        provider = "lmstudio";
        id = "qwen3.6-35b";
        title = "Qwen3.6 35B A3B";
        role = "primary";
    }
    {
      provider = "lmstudio";
      id = "qwen3-coder";
      title = "Qwen3 Coder Next 80B MLX 4bit";
      role = "available";
    }
  ];

  validRoles = [ "primary" "available" null ];

  invalidRoleModels = builtins.filter
    (m: !(builtins.elem (m.role or null) validRoles))
    models;

  roleValidation =
    if invalidRoleModels == [ ] then
      true
    else
      let
        badModel = builtins.head invalidRoleModels;
        badRole = badModel.role or null;
      in
      throw "Invalid role '${toString badRole}' for model '${badModel.provider}/${badModel.id}' in modules/home/opencode/models.nix. Allowed roles: primary, available, or omit role.";

  modelRef = m: "${m.provider}/${m.id}";

  findByRole = role:
    let
      matches = builtins.filter (m: (m.role or null) == role) models;
    in
    if builtins.length matches == 1 then
      builtins.head matches
    else
      throw "Expected exactly one model with role '${role}' in modules/home/opencode/models.nix";

  modelsForProvider = providerName:
    builtins.listToAttrs (
      map (m: {
        name = m.id;
        value = { name = m.title; };
      })
      (builtins.filter (m: m.provider == providerName) models)
    );

  provider = builtins.mapAttrs
    (providerName: providerConfig:
      providerConfig // {
        models = modelsForProvider providerName;
      })
    providers;

  primaryModel = findByRole "primary";
in
assert roleValidation;
{
  model = modelRef primaryModel;
  inherit provider;
}
