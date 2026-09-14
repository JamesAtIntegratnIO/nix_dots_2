{ pkgs, username, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  hermesPackages = inputs.hermes-agent.packages.${system};

  # Choose the base package; switch to hermesPackages.messaging or
  # hermesPackages.full if you need those dependency groups sealed at build time.
  hermesPackage = hermesPackages.default;

  # Matt Pocock skills — shared derivation, installed to ~/.agents/mattpocock-skills
  mattpocockSkills = pkgs.callPackage ../../nix/mattpocock-skills {};

  mattpocockSkillsDir = pkgs.stdenvNoCC.mkDerivation {
    name = "mattpocock-skills-hermes";
    nativeBuildInputs = [ pkgs.coreutils ];
    src = mattpocockSkills;
    installPhase = ''
      mkdir -p "$out/skills"
      cp -rL ${mattpocockSkills}/skills/. "$out/skills/"
    '';
  };

  # Non-secret baseline config. Keep provider credentials in ~/.hermes/.env.
  hermesConfig = (pkgs.formats.yaml {}).generate "hermes-config.yaml" {
    model.default = "anthropic/claude-sonnet-4";
    terminal = {
      backend = "local";
      timeout = 180;
    };
    toolsets = [ "all" ];
    skills.external_dirs = [
      "/Users/${username}/.agents/mattpocock-skills/skills"
    ];
  };
in
{
  home.packages = [ hermesPackage ];

  home.sessionVariables = {
    HERMES_HOME = "/Users/${username}/.hermes";
  };

  home.file.".hermes/config.yaml".source = hermesConfig;

  home.file.".agents/mattpocock-skills" = {
    source = mattpocockSkillsDir;
    recursive = true;
    force = true;
  };

  home.file.".hermes/.env.example".text = ''
    # Copy to ~/.hermes/.env and add your real keys. Do not commit secrets.
    OPENROUTER_API_KEY=replace-me
    # ANTHROPIC_API_KEY=replace-me
  '';
}
