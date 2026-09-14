{}:
{
  mkScopedEditPermission = files:
    builtins.listToAttrs (
      [{
        name = "*";
        value = "deny";
      }]
      ++ map (file: {
        name = file;
        value = "allow";
      }) files
    );

  commonPermission = {
    read = "allow";
    edit = "allow";
    glob = "allow";
    grep = "allow";
    list = "allow";
    skill = "allow";
    question = "allow";
    webfetch = "allow";
    websearch = "allow";
    external_directory = "ask";
    doom_loop = "allow";
    lsp = "allow";
  };

  mkSubagentPermission = bash: {
    read = "allow";
    edit = "allow";
    glob = "allow";
    grep = "allow";
    list = "allow";
    skill = "allow";
    question = "allow";
    webfetch = "allow";
    websearch = "allow";
    external_directory = "ask";
    doom_loop = "allow";
    task = "deny";
    lsp = "allow";
    inherit bash;
  };

  # Shared "Project Rule Awareness" section — extracted to avoid 6 lines of
  # identical text duplicated across all 10 agent definitions (60 lines total).
  projectRuleAwareness = ''

    ## Project Rule Awareness

    Before planning or executing any non-trivial task, check for a project-level AGENTS.md in the current working tree. If it exists, treat its instructions as mandatory constraints.

    - If project AGENTS.md and global instructions conflict, prioritize the project AGENTS.md for project-specific behavior.
    - Re-check AGENTS.md whenever the task scope changes.
    - If an instruction is ambiguous, ask the user before proceeding.
  '';
}