# Desktop Environments

## Overview

NixIT supports three desktop environments, all sharing a common base (`modules/desktop/`) that provides PipeWire audio, Bluetooth, GPU drivers, Thunar, polkit, NetworkManager, and printing.

Each DE has two files:
- `default.nix` — system-level NixOS config (display manager, packages, fonts)
- `home.nix` — home-manager config (theming, keybinds, terminal, shell prompt)

The `desktopEnvironment` variable (passed via `home-manager.extraSpecialArgs`) controls which `home.nix` gets imported.

## Hyprland

**Path:** `modules/wm/hyprland/`

Tiling Wayland compositor running the **Caelestia QuickShell rice** via the
official `caelestia-shell` flake (`programs.caelestia`, started as a systemd user
service). Caelestia provides the bar, notifications, launcher, OSD, dashboard, and
wallpaper — so waybar/mako/hyprpaper are disabled in `home.nix`.

| Component | Tool |
|-----------|------|
| Compositor | Hyprland (UWSM + XWayland) |
| Display Manager | SDDM (X11 greeter) |
| Shell (bar/notifs/launcher/OSD/dashboard/wallpaper) | Caelestia (QuickShell) |
| Fallback launcher | Fuzzel (`Super+Space`) |
| Terminal | Foot |
| Lock Screen | Hyprlock + Hypridle |
| Prompt | Starship |
| Logout | wlogout |

Set the wallpaper after first login: `caelestia wallpaper -f <path>`. Caelestia
drawers: `Super+A` (dashboard), `Super+R` (launcher) — verify drawer names with
`caelestia shell drawers list`.

**Key bindings:**

| Shortcut | Action |
|----------|--------|
| `Super + T` | Terminal |
| `Super + W` | Browser (Zen) |
| `Super + Space` | App launcher (Fuzzel) |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + L` | Lock screen |
| `Super + V` | Clipboard history |
| `Super + 1-0` | Switch workspace |
| `Super + Alt + 1-0` | Move window to workspace |
| `Print` / `Super+Shift+S` | Screenshot (area) |

## GNOME

**Path:** `modules/wm/gnome/`

Traditional Wayland desktop with GDM display manager. All GNOME core apps are disabled — only the shell and essential tools are installed.

| Component | Tool |
|-----------|------|
| Desktop | GNOME Shell (Wayland) |
| Display Manager | GDM |
| Terminal | Foot |
| Prompt | Starship |
| Theme | Catppuccin Mocha GTK |
| Icons | Papirus Dark |
| Cursors | Bibata Modern Classic |

**dconf settings applied via home-manager:**
- Dark mode enabled
- Custom keybinding: `Super + T` opens Foot terminal
- Window buttons: minimize, maximize, close

## KDE Plasma 6

**Path:** `modules/wm/kde/`

Full-featured Plasma 6 desktop with Wayland. Uses the new Plasma Login Manager (SDDM is deprecated on nixpkgs-unstable).

| Component | Tool |
|-----------|------|
| Desktop | KDE Plasma 6 (Wayland) |
| Display Manager | Plasma Login Manager |
| Terminal | Foot |
| Prompt | Starship |
| Theme | Catppuccin KDE |
| Icons | Papirus |
| Cursors | Bibata Modern Classic |

## Shared Across All DEs

All desktop environments include:
- **Spicetify** — themed Spotify (Caelestia theme from caelestia-dots)
- **VS Code** — with vim, nix-ide, Catppuccin theme
- **Zen Browser** — with custom userChrome.css
- **Starship** prompt — consistent powerline-style prompt
- **Foot** terminal — lightweight Wayland terminal
- **Git** — preconfigured with user identity

## Adding a New DE

1. Create `modules/wm/my-de/default.nix` (system-level: display manager, packages, fonts)
2. Create `modules/wm/my-de/home.nix` (home-manager: theming, terminal, keybinds)
3. Add one line to `nixosConfigurations` in `flake.nix` — the `mkDesktop` helper
   wires in core + desktop + `modules/wm/<de>` + home-manager for you:
   ```nix
   desktop-my-de = mkDesktop "my-de";
   ```
4. `nix flake check` to confirm it evaluates, then `./scripts/install-host.sh
   desktop-my-de root@<ip>` (or `deploy .#desktop-my-de` to update).

## Dev workstation VM (`svgmdl-devl-01`)

A separate graphical VM built on the desktop base + `modules/wm/gnome` +
`modules/dev` (unstable nixpkgs). Lean — **no home-manager ricing**: GNOME plus a
full dev toolchain (Rust, Python, C#/.NET, Docker) with VS Code **Insiders**,
Neovim, GitHub CLI, and the **Helium** browser (not Zen). See
[../hosts/svgmdl-devl-01/README.md](../hosts/svgmdl-devl-01/README.md).

## Keyboard Layout

Swiss German everywhere:
- Console (TTY): `console.keyMap = "sg"` — set **once** fleet-wide in `modules/core`.
- Graphical (greeter/X): `services.xserver.xkb.layout = "ch"; variant = "de";` in each DE.
- GNOME Wayland session: pinned to `ch+de` via system dconf (`org/gnome/desktop/input-sources`).
- Hyprland Wayland session: `kb_layout = ch; kb_variant = de;` in its config.
