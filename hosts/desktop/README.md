# desktop — workstation

Unstable nixpkgs + home-manager. One host dir, three flake configs:
`desktop` (Hyprland), `desktop-gnome`, `desktop-kde`.

## Files
- `disk.nix` — disko layout; **set `device` to your real disk** before installing.
- `hardware-configuration.nix` — bootloader + initrd modules. On real hardware,
  regenerate the hardware bits with `nixos-generate-config --no-filesystems`
  (disko owns the filesystems — don't let it re-add them).
- `network.nix`, `users.nix`, `platform.nix`.

## Install / update
- Fresh install: `./scripts/install-host.sh desktop root@<ip>`
  (or `desktop-gnome` / `desktop-kde`).
- Locally on the box: `nix-rebuild`. Remotely: `deploy .#desktop`.

## Secrets
`kuze/password` in `sops secrets/common.yaml`. SSH key login works regardless, so
a missing password never locks you out.

## Switch / add a desktop environment
Deploy a different config name (`desktop-gnome`, `desktop-kde`) — same host dir,
different WM module. Add a new DE with one line in `flake.nix`:
`desktop-<de> = mkDesktop "<de>";` (after creating `modules/wm/<de>/`).
