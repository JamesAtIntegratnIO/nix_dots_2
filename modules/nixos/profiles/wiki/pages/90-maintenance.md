# Maintenance

The `nix_dots_2` flake defines this deck (host `pocketterm`); the aarch64 Mac
Studio builds it. No on-device compiling.

## Deploy (from the repo on the Mac)

    nixos-rebuild switch --flake .#pocketterm \
      --target-host jdreier@pocketterm --use-remote-sudo

Firmware / `config.txt` changes (e.g. USB current) need a reboot; everything
else goes live on switch.

    nix flake update                             # bump inputs, then redeploy
    nixos-rebuild build --flake .#pocketterm     # build only, no activate

## Generations & rollback (on the deck)

    nixos-rebuild list-generations
    sudo nixos-rebuild switch --rollback         # back one generation
    sudo nix-collect-garbage -d                  # reclaim space
    sudo nix-collect-garbage --delete-older-than 14d

## First install / reflash

Flash the image from `.#pocketterm-sdimage`, boot once, then use `target-host`
rebuilds. After a reflash, set a login password with `passwd` (SSH stays
key-only).

## Health checks

    systemctl --failed                           # broken units
    journalctl -b -p err                         # errors this boot
    journalctl -u <unit> -e                      # tail one unit
    ip route                                     # one default via wld0

## Where things live

    hosts/pocketterm/default.nix                         # host
    modules/nixos/profiles/pocketterm-hardware.nix       # Pi 5 / panel / touch / USB
    modules/nixos/profiles/wayland-kiosk.nix             # Sway / keybinds
    modules/nixos/profiles/cyberdeck/                    # look & feel
    modules/nixos/profiles/{workspaces,quickmenus,screen-dim,power,emulation,pentest}
    modules/nixos/profiles/wiki/pages/*.md               # this wiki

## Edit this wiki

1. Add/edit a `.md` in `modules/nixos/profiles/wiki/pages/` (numeric prefix
   orders it; first `# Heading` is the title).
2. Deploy (above). `wiki` reads from the read-only Nix store, no daemon.
