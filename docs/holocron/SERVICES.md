# Services

Local AI services: Qdrant and Ollama. Both run as `launchd` user agents.

## Service Matrix

| Service | Address | Port(s) | Default State | Toggle |
|---|---|---|---|---|
| **Qdrant** | `127.0.0.1` | 6333 (HTTP), 6334 (gRPC) | **Enabled** | always on |
| **Ollama** | `127.0.0.1` | 11434 | **Disabled** | `enableOllama = true` in `local-ai.nix` |

## Shared Paths

All services share a common directory structure:

| Purpose | Path |
|---|---|
| **Config** | `/etc/local-ai/qdrant.yaml` |
| **Data** | `~/Library/Application Support/local-ai/` |
| **Logs** | `~/Library/Logs/local-ai/` |

The activation script (in `modules/darwin/local-ai.nix`) creates these directories and chowns them to the user on every rebuild.

---

## Qdrant

A vector database for semantic search and memory storage. Used by the Qdrant MCP server that opencode agents connect to.

### Configuration

| Setting | Value | Source |
|---|---|---|
| **Config file** | `/etc/local-ai/qdrant.yaml` | `environment.etc."local-ai/qdrant.yaml"` |
| **Storage path** | `~/Library/Application Support/local-ai/qdrant/` | `qdrantDataDir` in `local-ai.nix` |
| **Working directory** | `~/Library/Application Support/local-ai/` | `WorkingDirectory` in service config |
| **HTTP API** | `http://127.0.0.1:6333` | `service.http_port` |
| **gRPC** | `127.0.0.1:6334` | `service.grpc_port` |
| **API host** | `127.0.0.1` | `service.host` |

### launchd Service

| Property | Value |
|---|---|
| **Label** | `org.nixos.qdrant` |
| **Program** | `$qdrant/bin/qdrant` |
| **Args** | `--config-path /etc/local-ai/qdrant.yaml` |
| **RunAtLoad** | `true` |
| **KeepAlive** | `true` |
| **Stdout** | `~/Library/Logs/local-ai/qdrant.log` |
| **Stderr** | `~/Library/Logs/local-ai/qdrant.err` |

### How to Verify It's Running

```bash
# Check the service status
launchctl print gui/$(id -u)/org.nixos.qdrant

# Check if the port is listening
lsof -i :6333

# Hit the health endpoint
curl http://127.0.0.1:6333/

# List collections (via the REST API)
curl http://127.0.0.1:6333/collections
```

### Troubleshooting

**Service not starting:**
```bash
# Check the error log
tail -n 50 ~/Library/Logs/local-ai/qdrant.err
```

**Crashing with path errors:**
The `WorkingDirectory` is set to the parent directory (`~/Library/Application Support/local-ai/`), not inside the storage path. This prevents Qdrant from trying to create subdirectories relative to a read-only Nix store path. If this was changed and Qdrant crashes, restore the WorkingDirectory to the parent dir.

**Corrupt database:**
```bash
# Stop the service
launchctl unload ~/Library/LaunchAgents/org.nixos.qdrant.plist 2>/dev/null || true

# Remove the data directory (this deletes all collections)
rm -rf ~/Library/Application\ Support/local-ai/qdrant

# Restart
launchctl load ~/Library/LaunchAgents/org.nixos.qdrant.plist 2>/dev/null || true
```

---

## Ollama

A local inference server. Disabled by default but fully wired up and ready to enable.

### Configuration

| Setting | Value |
|---|---|
| **Address** | `127.0.0.1:11434` |
| **Models directory** | `~/Library/Application Support/local-ai/ollama/` |
| **Program** | `$ollama/bin/ollama serve` |
| **Stdout** | `~/Library/Logs/local-ai/ollama.log` |
| **Stderr** | `~/Library/Logs/local-ai/ollama.err` |

### How to Enable

1. Open `modules/darwin/local-ai.nix`
2. Change `enableOllama = false;` to `enableOllama = true;`
3. Rebuild:
   ```bash
   darwin-rebuild switch --flake .#holocron
   ```
4. The service starts automatically (`RunAtLoad = true`, `KeepAlive = true`).

### How to Verify It's Running

```bash
# Check the service
launchctl print gui/$(id -u)/org.nixos.ollama

# Check the API
curl http://127.0.0.1:11434/api/tags

# Pull a model (first time)
ollama pull qwen3:8b

# Test inference
curl http://127.0.0.1:11434/api/generate -d '{
  "model": "qwen3:8b",
  "prompt": "Hello, world",
  "stream": false
}'
```

### How to Disable

1. Set `enableOllama = false;` in `local-ai.nix`
2. Rebuild

The models directory and logs remain on disk. The service stops.

---

## General Service Management

### Restart a Service

```bash
# Unload, then load (equivalent to restart)
launchctl unload ~/Library/LaunchAgents/org.nixos.qdrant.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/org.nixos.qdrant.plist 2>/dev/null || true
```

### View Logs in Real-Time

```bash
tail -f ~/Library/Logs/local-ai/qdrant.log
tail -f ~/Library/Logs/local-ai/qdrant.err
tail -f ~/Library/Logs/local-ai/ollama.log
tail -f ~/Library/Logs/local-ai/ollama.err
```

### Check All Local AI Services

```bash
for label in org.nixos.qdrant org.nixos.ollama; do
  echo "=== $label ==="
  launchctl print gui/$(id -u)/$label 2>&1 | head -5
  echo
done
```

---

## Host metrics (system daemons)

Defined in `modules/darwin/host-metrics.nix` and `modules/darwin/github-runner.nix`. Unlike the AI services above these are `launchd` **system daemons**, because the runners they report on are system daemons too. pitdroid runs the same pair from `modules/nixos/host-metrics.nix`.

| Daemon label | What it does | Listens |
|---|---|---|
| `io.integratn.node-exporter` | node_exporter, plus the textfile collector in `/var/db/node-exporter-textfile` | `127.0.0.1:9100` |
| `io.integratn.prometheus-agent` | Prometheus in agent mode: scrapes node_exporter every 30s and remote-writes to `https://prom-remote.cluster.integratn.tech/api/v1/write` with `host=holocron`, job `host-node` | `127.0.0.1:9201` |
| `io.integratn.ghrunner.metrics` | Every 60s writes `github_runner_up{runner}` and `github_runner_busy{runner}` into the textfile directory | — |

Push, not scrape: holocron sits on the IoT VLAN, so the cluster never has to reach in. The job is `host-node`, not `node-exporter`, so kube-prometheus-stack's node rules don't treat these hosts as cluster nodes. Alerts and the landing page's Hosts tab live in gitops_homelab_2_0.

```bash
sudo launchctl print system/io.integratn.prometheus-agent | grep state
curl -s 127.0.0.1:9100/metrics | grep github_runner_
tail /var/log/prometheus-agent.log
```

## RustDesk

`launchd.agents.rustdesk` in `modules/darwin/home/remote-dev.nix` runs RustDesk's direct server on port 21118 for carbonite over Tailscale. The agent has `KeepAlive = true` and `ThrottleInterval = 30`, and it clears stale `/tmp/RustDesk-<uid>` sockets when no RustDesk is running. On 2026-10-14 RustDesk exited 0 after an IPC "Address already in use" clash, and the old `SuccessfulExit = false` policy never restarted it.

```bash
launchctl print gui/$(id -u)/org.nix-community.home.rustdesk | grep -E 'state|last exit'
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.rustdesk
```
