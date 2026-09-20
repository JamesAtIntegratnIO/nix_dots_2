# NixOS laptop and Mac Studio configuration

This flake manages the NixOS host `nixos` and Apple Silicon Mac `mac-studio`.
Host-specific hardware and identity live under `hosts/`; operating-system
configuration lives under `modules/nixos/` and `modules/darwin/`.

## Layout

```text
.
├── flake.nix
├── flake.lock
├── hosts/
│   ├── mac-studio/
│   │   └── default.nix
│   └── nixos/
│       ├── default.nix
│       └── hardware-configuration.nix
├── home/
│   ├── boboysdadda/
│   └── jdreier/
└── modules/
    ├── darwin/
    └── nixos/
        ├── core/
        └── profiles/
```

- `hosts/nixos/default.nix` composes this laptop and owns its hostname, users,
  kernel choice, and `system.stateVersion`.
- `hardware-configuration.nix` contains generated, machine-specific device
  settings. Regenerate it only when the hardware or disk layout changes.
- The upstream `nixos-hardware` ThinkPad X1 Carbon Gen 9 profile supplies
  model-specific hardware quirks and defaults.
- `modules/nixos/core` contains baseline settings shared by every future host.
- `modules/nixos/profiles` contains optional roles such as a Cinnamon desktop
  or laptop power management.
- `home/boboysdadda` contains user-scoped shell, Git, editor, and development
  configuration managed by Home Manager as part of the system rebuild.
- `hosts/mac-studio/default.nix` supplies the Mac's module list in its original
  order; `home/jdreier` forwards its preserved Home Manager module.

## Apply

From this directory, inspect and build before switching:

```console
nix flake check
sudo nixos-rebuild dry-activate --flake .#nixos
sudo nixos-rebuild switch --flake .#nixos
```

After changing an input, review and commit the lock-file update:

```console
nix flake update
```

Format Nix files with:

```console
nix fmt
```

Enter the repository's maintenance environment with:

```console
nix develop
```

## Mac Studio

`hosts/mac-studio/default.nix` composes the existing `jdreier` Mac environment.
Its imported system, Home Manager, OpenCode, and Hermes modules live under
`modules/darwin`; `home/jdreier/default.nix` is the user entry point.
Mac-specific service and agent documentation is under `docs/mac-studio`.

The import preserves the Mac's original package pins, LM Studio overlay,
Qdrant and Colima launchd agents,
Docker plugins, shell/Git settings, and OpenCode/Hermes configuration and skills.
Ollama stays installed with its service disabled. Existing data and credentials
remain at their original `/Users/jdreier` paths. Nix management stays disabled
in nix-darwin (`nix.enable = false`), as in the original configuration.

The `darwin-nixpkgs` and `darwin-home-manager` inputs retain the Mac's original
versions separately from the laptop's inputs. Integration does not upgrade them.

On the Mac, from a copy of this repository, build and inspect before switching:

```console
nix build .#darwinConfigurations.mac-studio.system
sudo darwin-rebuild switch --flake .#mac-studio
```

Evaluate the Mac target from either machine with:

```console
nix eval --raw .#darwinConfigurations.mac-studio.system.drvPath
```

Update the LM Studio pin with `bash scripts/update-lmstudio.sh`; the script
edits `modules/darwin/overlays.nix` relative to its own location.

## Tailscale

Both hosts enable Tailscale through Nix: systemd on NixOS and a system launchd
daemon on macOS. The Mac uses the CLI-only `tailscaled` variant for unattended
access. Check for an existing Tailscale.app or separately installed daemon
before activating the Mac configuration; run one installation at a time.

After rebuilding each host, enroll both in the same Tailscale account:

```console
sudo tailscale up
tailscale status
tailscale ip -4
```

Open each sign-in URL in your browser. No authentication keys belong in the
flake. Enable MagicDNS in the Tailscale admin console, then verify connectivity
from the laptop with `tailscale ping mac-studio`. The Mac's Nix module configures
resolution for its full `*.ts.net` name; use the full name or its Tailscale IP if
the short hostname does not resolve.

Existing macOS Remote Login supplies SSH:

```console
ssh jdreier@<mac-studio-tailscale-ip>
```

The NixOS firewall allows Tailscale's encrypted UDP transport on port 41641.
Access to services is still controlled by their listeners, host firewalls, and
your tailnet policy. Test access from another network before relying on it
while traveling, including after a reboot and FileVault unlock.

## Remote development on the Studio

The laptop's `home/boboysdadda/remote-dev.nix` provides a verified SSH host key
and the `studio` alias for `jdreier@mac-studio.chimera-mooneye.ts.net`.
Connections use SSH keys, share a connection for ten minutes, and send
keepalives to detect a dropped network connection.

| Command | Behavior |
| --- | --- |
| `ssh studio` | Open a shell on the Mac over Tailscale |
| `studio` | Create or reattach to the persistent `dev` tmux session in `~/Projects` |
| `studio my-project` | Create or reattach to a named session |
| `scp ./file studio:Projects/` | Copy a file to the Studio |
| `studio-code` | Open the Studio's Projects directory in VS Code Remote SSH |
| `ssh -N -L 3000:127.0.0.1:3000 studio` | Access the Studio's port 3000 at laptop `localhost:3000` |

Detach from tmux with `Ctrl+Space`, then `d`; reconnect with the same `studio`
command. If inside the laptop's tmux already, press `Ctrl+Space` twice to send
the prefix to the remote tmux. Processes survive disconnections, but not a Mac
reboot. VS Code Remote SSH and the `studio-code` alias are managed by the
laptop's Home Manager configuration and take effect after rebuilding.

For immediate use, the SSH configuration and Studio tmux configuration were
built through Nix and linked into place, with GC roots under each user's
`~/.local/state/nix/remote-dev`. The laptop's `studio` command and the Mac's
tmux package were also installed in their Nix user profiles. The next system
rebuild manages these tools through Home Manager as well.

The host key pin is public, not a login credential. If the Mac is reinstalled
or its SSH keys are rotated, verify the replacement key on the Mac before
updating this module. The SSH configuration deliberately checks this key.

## AI

`home/boboysdadda/ai.nix` manages the AI tools:

| Tool | GUI | CLI |
| --- | --- | --- |
| Claude | Claude Desktop (`claude-desktop`) | `claude` (Claude Code) |
| Codex | OpenAI desktop app (`chatgpt`), select Codex | `codex` |

Both GUIs use the vendors' official Linux desktop binaries in Nix FHS
environments. Claude's packaging comes from the pinned
[claude-desktop-debian source](https://github.com/aaddrick/claude-desktop-debian).
The [OpenAI Linux preview](https://learn.chatgpt.com/docs/linux/linux-app)
includes Codex; `pkgs/codex-desktop.nix` pins its version and checksum.
NixOS is outside the vendors' officially supported distributions.
After rebuilding, launch the desktop apps from the application menu or use the
commands above and sign in. Credentials stay outside this flake.

## Cinnamon fullscreen spaces

Fullscreen windows automatically move to a new workspace. Leaving fullscreen
returns the window to its original workspace; empty spaces created by the
extension are removed. Maximizing a window keeps it on the current workspace.
Start with one normal workspace so fullscreen spaces follow it directly.
Workspace navigation wraps between the first and last workspace.
Fullscreen workspaces are named after their application (for example, Firefox).

- `Super+F`: toggle fullscreen for the focused window.
- `Ctrl+Left` / `Ctrl+Right`: switch workspaces (also `Ctrl+Super+Left/Right` and `Ctrl+Alt+Left/Right`).
- `Ctrl+Super+Up`: open Cinnamon's Expo workspace overview.

Rebuild using the commands above, then log out and back in to load the extension.
The local extension targets Cinnamon 6.6. Workspaces span monitors, so this differs
from macOS's per-monitor Spaces. The extension can be disabled in Cinnamon's
Extensions settings.

## Studio remote desktop

Run `studio-desktop` on the laptop to open RustDesk directly to the Mac Studio
over Tailscale (`100.118.166.83:21118`). Both apps are installed through Nix:
Linux uses `rustdesk-flutter`; macOS uses the checksum-pinned official Apple
Silicon app in `modules/darwin/rustdesk-package.nix`. The Mac app is installed
through `environment.systemPackages`, so `mac-app-util` gives it a Spotlight
trampoline, and its user launch agent starts at login.

On the Mac, approve RustDesk under System Settings → Privacy & Security →
Screen & System Audio Recording, Accessibility, and Input Monitoring if requested.
In RustDesk → Settings → Security, set a permanent password for unattended
access. Save it in your password manager; passwords and RustDesk identity files
are not managed by this repository. The laptop client can remember the password.

The Mac configuration merges direct-access settings into its existing
`RustDesk2.toml`, preserving credentials. Its IP whitelist permits this laptop's
Tailscale address (`100.91.78.45`); update it when adding another client. Direct
connections need no public relay server or router port forwarding. The user
agent runs after Mac login; access before login requires RustDesk's privileged
service setup. macOS permission approvals cannot be provisioned by this flake.

## Adding another host

Create `hosts/<hostname>/default.nix` and its generated hardware configuration,
then add another `nixosConfigurations.<hostname>` entry in `flake.nix`. Compose
existing profiles instead of copying their settings.

Secrets should never be committed as plain Nix strings. Add a secrets manager
(for example, sops-nix or agenix) when secrets need to become declarative.
