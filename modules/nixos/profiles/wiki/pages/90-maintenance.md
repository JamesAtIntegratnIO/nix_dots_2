# Maintenance

The `nix_dots_2` flake defines this deck (host `pocketterm`), and the aarch64
Mac Studio builds it. No on-device compiling.

## Deploy a change

From the repo on the Mac:

    nixos-rebuild switch --flake .#pocketterm \
      --target-host jdreier@pocketterm --use-remote-sudo

It builds on the Mac (or its linux-builder), copies the closure over SSH, and
activates. Firmware and `config.txt` changes (e.g. USB current) need a
**reboot** to take effect; most everything else goes live on switch.

## First install / reflash

Flash the SD image built from `.#pocketterm-sdimage`, boot once, then use
`target-host` rebuilds from then on. After a reflash, set a login password with
`passwd` (SSH stays key-only regardless).

## Where things live

- Host: `hosts/pocketterm/default.nix`
- Hardware (Pi 5 / panel / touch / USB current): `modules/nixos/profiles/pocketterm-hardware.nix`
- Desktop / keybinds: `modules/nixos/profiles/wayland-kiosk.nix`
- Look & feel: `modules/nixos/profiles/cyberdeck/`
- Workspaces, quick menus, screen-dim, power, emulation, pentest: their own
  files under `modules/nixos/profiles/`
- This wiki: `modules/nixos/profiles/wiki/pages/*.md`

## Editing this wiki

1. Edit or add a `.md` file in `modules/nixos/profiles/wiki/pages/`. Filenames
   sort by their numeric prefix, and the first `# Heading` becomes the title.
2. Deploy (command above).
3. `wiki` picks it up. It reads from the read-only Nix store, so there's no
   database and nothing running in the background.

## Health checks

    systemctl --failed          # anything broken?
    journalctl -b -p err        # errors this boot
    ip route                    # one default via wld0 (see Networking)
