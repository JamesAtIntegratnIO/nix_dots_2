{ config, pkgs, lib, username, ... }:
let
  logDir = "/Users/${username}/Library/Logs/local-ai";
  qdrantDataDir = "/Users/${username}/Library/Application Support/local-ai/qdrant";
  enableOllama = false;
in
{
  # Keep the local AI directories writable for launchd user agents.
  # Qdrant writes temporary snapshot data relative to CWD.
  # The ollama models directory is also created here so the service starts
  # correctly when `enableOllama` is flipped to true.
  system.activationScripts.localAiDirs.text = ''
    /bin/mkdir -p "${logDir}" "${qdrantDataDir}" \
                 "/Users/${username}/Library/Application Support/local-ai/ollama"

    /usr/sbin/chown -R ${username}:staff "/Users/${username}/Library/Logs/local-ai" "/Users/${username}/Library/Application Support/local-ai"
  '';

  # Qdrant vector-database config.
  environment.etc."local-ai/qdrant.yaml".text = ''
    storage:
      storage_path: ${qdrantDataDir}

    service:
      host: 127.0.0.1
      http_port: 6333
      grpc_port: 6334
  '';

  # Keep the service definition in-tree but disabled by default.
  # Flip to true when you want local Ollama inference back.
  launchd.user.agents.ollama = lib.mkIf enableOllama {
    serviceConfig = {
      Label = "org.nixos.ollama";
      ProgramArguments = [ "${pkgs.ollama}/bin/ollama" "serve" ];
      EnvironmentVariables = {
        OLLAMA_HOST = "127.0.0.1:11434";
        OLLAMA_MODELS = "/Users/${username}/Library/Application Support/local-ai/ollama";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/ollama.log";
      StandardErrorPath = "${logDir}/ollama.err";
    };
  };

  # Qdrant vector database.
  launchd.user.agents.qdrant = {
    serviceConfig = {
      Label = "org.nixos.qdrant";
      # Use the parent directory as WorkingDirectory to avoid fragile relative
      # path resolution when Qdrant creates subdirectories within storage_path.
      WorkingDirectory = "/Users/${username}/Library/Application Support/local-ai/";
      ProgramArguments = [
        "${pkgs.qdrant}/bin/qdrant"
        "--config-path" "/etc/local-ai/qdrant.yaml"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/qdrant.log";
      StandardErrorPath = "${logDir}/qdrant.err";
    };
  };

}
