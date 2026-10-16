# This host's metrics, pushed to the homelab's Prometheus.
#
# node_exporter listens on loopback only and a Prometheus in agent mode
# scrapes it and remote-writes to prom-remote.cluster.integratn.tech, the same
# receiver vcluster-media's agent writes to. Pushing means the cluster never
# has to reach this host, so no firewall rule between VLANs is needed, and a
# host that stops pushing is what the cluster alerts on
# (HostNotReporting in gitops_homelab_2_0's host-exporters addon).
#
# Every series carries `host` (the hostname) and job="host-node". The job is
# deliberately not "node-exporter": kube-prometheus-stack's node rules match
# that job and would misfire on a host they were not written for.
#
# The textfile directory is where other modules drop extra series:
# github-runner.nix writes github_runner_up and github_runner_busy there.
{ config, ... }:
let
  textfileDir = "/var/lib/node-exporter-textfile";
in
{
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [ "systemd" ];
    extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
  };

  systemd.tmpfiles.rules = [ "d ${textfileDir} 0755 root root -" ];

  services.prometheus = {
    enable = true;
    enableAgentMode = true;
    listenAddress = "127.0.0.1";
    port = 9201;
    globalConfig = {
      scrape_interval = "30s";
      external_labels.host = config.networking.hostName;
    };
    scrapeConfigs = [
      {
        job_name = "host-node";
        static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
      }
    ];
    remoteWrite = [ { url = "https://prom-remote.cluster.integratn.tech/api/v1/write"; } ];
  };
}
