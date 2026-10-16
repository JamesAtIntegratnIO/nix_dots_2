# This Mac's metrics, pushed to the homelab's Prometheus. The darwin twin of
# modules/nixos/host-metrics.nix; read that for why it pushes.
#
# node_exporter runs as nobody on loopback; a Prometheus in agent mode scrapes
# it and remote-writes to prom-remote.cluster.integratn.tech. The Mac sits on
# the IoT VLAN, so the cluster could not scrape it without a firewall rule;
# going out to the gateway it already reaches needs none.
#
# Both are `command`s, not ProgramArguments, so nix-darwin wraps them in
# /bin/wait4path /nix/store: at boot launchd starts daemons before the Nix
# volume is mounted (github-runner.nix has the failure this avoids).
#
# github-runner.nix writes github_runner_up and github_runner_busy into the
# textfile directory.
{ pkgs, lib, hostname, ... }:
let
  textfileDir = "/var/db/node-exporter-textfile";
  agentDir = "/var/db/prometheus-agent";

  agentConfig = (pkgs.formats.yaml { }).generate "prometheus-agent.yml" {
    global = {
      scrape_interval = "30s";
      external_labels.host = hostname;
    };
    scrape_configs = [
      {
        job_name = "host-node";
        static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
      }
    ];
    remote_write = [ { url = "https://prom-remote.cluster.integratn.tech/api/v1/write"; } ];
  };
in
{
  launchd.daemons.node-exporter = {
    command = lib.escapeShellArgs [
      "${pkgs.prometheus-node-exporter}/bin/node_exporter"
      "--web.listen-address=127.0.0.1:9100"
      "--collector.textfile.directory=${textfileDir}"
    ];
    serviceConfig = {
      Label = "io.integratn.node-exporter";
      UserName = "nobody";
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Background";
      StandardErrorPath = "/var/log/node-exporter.log";
    };
  };

  launchd.daemons.prometheus-agent = {
    command = "/bin/sh -c ${lib.escapeShellArg ''
      mkdir -p ${agentDir}
      exec ${pkgs.prometheus}/bin/prometheus --agent \
        --config.file=${agentConfig} \
        --storage.agent.path=${agentDir} \
        --web.listen-address=127.0.0.1:9201
    ''}";
    serviceConfig = {
      Label = "io.integratn.prometheus-agent";
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Background";
      StandardErrorPath = "/var/log/prometheus-agent.log";
    };
  };
}
