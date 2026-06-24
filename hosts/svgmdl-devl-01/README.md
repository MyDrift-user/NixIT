# svgmdl-devl-01 — developer workstation VM

Graphical VM (GNOME) with a full dev toolchain. Built on the desktop stack
(`modules/desktop` + `modules/wm/gnome`) plus `modules/dev`; uses **unstable**
nixpkgs for fresh tooling. Browser is **Helium** (not zen — this host skips the
`home/kuze` desktop config on purpose, so it's lean: GNOME + dev stuff).

## What's in it (`modules/dev`)
- **Editors:** VS Code **Insiders** (`code-insiders`, daily build via flake), Neovim
- **VCS:** git (identity preset), `gh`, lazygit
- **Rust:** rustc, cargo, rust-analyzer, clippy, rustfmt
- **Python:** python3, pip, uv, ruff, pyright
- **C#/.NET:** dotnet-sdk 9
- **Docker:** engine + docker-compose + lazydocker (`kuze` is in the `docker` group)
- **Build:** gcc, make, pkg-config · **CLI:** ripgrep, fd, jq, fastfetch
- **Browser:** Helium

## Deploy
1. Secret: `kuze/password` in `sops secrets/common.yaml` (shared; already listed).
   No newt — this is a workstation, not a Pangolin-fronted service.
2. Set `device` in `disk.nix` if not `/dev/sda`.
3. `./scripts/install-host.sh svgmdl-devl-01 root@<ip>` → `deploy .#svgmdl-devl-01`.
4. Log in to GNOME as `kuze`.

## Notes
- DE is GNOME (works well in VMs). Switch by swapping `./modules/wm/gnome` for
  `kde`/`hyprland` in the flake entry.
- Helium comes from a flake input (`helium`); `nix flake update` refreshes it.
- VS Code **Insiders** is built from MS's live "latest insider" tarball in
  `modules/dev`. To update it, re-prefetch and paste the new hash (command is in
  `modules/dev/default.nix`).
- Want the full themed home-manager setup instead of lean? Add the
  `home-manager` block (like the desktop configs) to the flake entry.
