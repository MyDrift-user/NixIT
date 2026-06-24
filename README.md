# NixIT

A production-grade NixOS deployment platform. One flake managing a fleet of VMs —
self-hosted services, desktops, a dev workstation, and domain controllers —
installed declaratively with disko + nixos-anywhere and pushed with deploy-rs.
Start at **[DEPLOY.md](DEPLOY.md)**.

## What's Included

**Desktop Environments** (pick one per machine)
- Hyprland — tiling Wayland compositor with Catppuccin theming
- GNOME — traditional Wayland desktop
- KDE Plasma 6 — full-featured desktop with Plasma Login Manager

**Server Roles** (mix and match)
- AD Domain Controller — Samba AD DC + internal DNS + NTP + internal CA
- RADIUS / NPS — FreeRADIUS with AD/LDAP backend (WPA2-Enterprise)
- RDP Session Host — xrdp multi-session with GNOME
- File Server — AD-integrated SMB shares
- DNS Forwarder — split-horizon DNS with Unbound
- DHCP Server — Kea DHCPv4
- Print Server — CUPS + Samba printer sharing
- Backup Server — BorgBackup repository
- Docker Host — container runtime with auto-pruning

**Infrastructure**
- Secrets management via sops-nix (age keys from SSH host keys)
- CIS-aligned hardening (nftables, sysctl, auditd, kernel protection)
- Declarative disk layout (disko) + one-command remote install (nixos-anywhere)
- Push deployments with automatic rollback (deploy-rs)
- CI that evaluates every host on push (`nix flake check`)

## Repository Structure

```
flake.nix              # Root flake — all hosts (mkServer/mkDesktop/mkAppServer helpers)
DEPLOY.md              # End-to-end deployment runbook (start here)
.sops.yaml             # sops-nix recipients (real age keys per host + admin)
secrets/               # Encrypted secrets (safe to commit); *.example = templates
scripts/
  install-host.sh      # disko + nixos-anywhere installer (seeds the host's sops key)
  gen-secrets.sh       # one-time secret/key bootstrap (writes plaintext to mdl-infra)
  gen-kuze-pw.sh       # (re)generate per-host kuze passwords

modules/
  core/                # ALL machines: aliases, packages, security, hardening, sops
  desktop/             # Shared desktop base (PipeWire, Bluetooth, graphics)
  wm/{hyprland,gnome,kde}/   # Desktop environments (system + home-manager)
  dev/                 # Dev workstation toolchain (Rust/Python/.NET/Docker, VSCode, Helium)
  server/              # Shared server base (SSH, fail2ban, firewall, docker) + proxmox.nix
  roles/               # Composable roles (ad-dc, radius, file-server, dhcp, …)
  services/            # One folder per deployed service (default.nix + README.md):
                       #   keycloak forgejo outline paperless immich headscale
                       #   excalidraw aliasvault kasm pelican moodleng rumi
                       #   freeipa samba-ad fortivpn-gateway

hosts/
  _common/server-host.nix   # Shared app-server base (disk, user, newt, nixit.* options)
  desktop/  mdl-server/  svgmdl-devl-01/  svgwdc-svpn-01/   # host dirs (disk + hw + users)

home/kuze/home.nix     # Home-manager (auto-imports the chosen DE's config)
iso/default.nix        # Minimal bootstrap ISO (SSH foothold for nixos-anywhere)
```

Most service VMs are one line in `flake.nix` (`mkAppServer`) — they have no
`hosts/<name>/` dir; the host *is* its `modules/services/<svc>/` module on the
shared `_common` base.

## Deploying

**→ [DEPLOY.md](DEPLOY.md) is the end-to-end runbook** (secrets → install → per-service
config → verify). Each VM also has its own README under `modules/services/<svc>/`.

## Quick Start

### Building the bootstrap ISO (optional)

Only needed for bare-metal targets you can't already SSH into; the ISO just
boots and enables SSH so nixos-anywhere can take over. VMs can skip it.

```bash
nix build .#nixosConfigurations.iso.config.system.build.isoImage
```

Write to USB: `dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress`

### Installing a machine (no manual setup)

The normal path is **nixos-anywhere** — it partitions the disk (via disko),
installs NixOS, and seeds the machine's sops key in one command, run from your
workstation. You do *not* need the ISO unless the target has no OS you can SSH
into.

```bash
./scripts/install-host.sh mdl-server root@<target-ip>
```

The target just needs to be booted into any Linux with SSH (the NixOS minimal
ISO, this repo's ISO, or nixos-anywhere's built-in kexec image). The disk layout
lives in `hosts/<host>/disk.nix` — set `device` to match the target first.
⚠️ **the target disk is wiped.**

The script pre-generates the host's SSH key, prints its age public key to paste
into `.sops.yaml`, then installs — so the very first boot can already decrypt
secrets. Adding a new host = add a `hosts/<host>/` dir + a `nixosConfigurations`
entry, then run the script.

For bare-metal with no network boot, build the ISO instead (see below) and
`nixos-anywhere --flake .#<host> root@<ip>` from another machine on the LAN.

### Updating an installed machine

Edit config in git, then **push** it with deploy-rs. If the new config breaks
connectivity, the host automatically rolls back instead of bricking:

```bash
nix run github:serokell/deploy-rs -- .#mdl-server
```

To pick up new upstream versions: `nix flake update` (or bump one input),
commit the lock, `nix flake check`, then deploy. For purely local changes on the
box itself, the `nix-rebuild` alias still works.

## Host Configurations

| Config | Channel | Description |
|--------|---------|-------------|
| `iso` | stable | Bootable installer ISO |
| `desktop` | unstable | Hyprland desktop |
| `desktop-gnome` | unstable | GNOME desktop |
| `desktop-kde` | unstable | KDE Plasma 6 desktop |
| `mdl-server` | stable | MDL Docker server |
| `svgwdc-svpn-01` | stable | FortiGate VPN client (openfortivpn) |
| `proxmox-server` | stable | Proxmox VM image |
| `svgmdl-devl-01` | unstable | Dev workstation VM (GNOME + Rust/Python/.NET/Docker + Helium) |

Plus nine single-purpose service VMs (`svgmdl-<svc>-01`) — see
[Service Hosts](#service-hosts).

Build a specific config:
```bash
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
nix build .#proxmox-image
```

## Adding a New Host

A service VM is one line in `flake.nix` (`mkAppServer`) + a `deploy.nodes` entry +
its `modules/services/<svc>/`. Full recipe (incl. secrets) in
**[DEPLOY.md §6](DEPLOY.md)**.

## Secrets Management

sops-nix; each host decrypts via an age key derived from its SSH host key. The
fleet is already bootstrapped — real keys + values exist, encrypted in `secrets/`,
with the plaintext source of truth kept **outside the repo** in
`../mdl-infra/deployments/`. Edit with:

```bash
export SOPS_AGE_KEY_FILE=../mdl-infra/deployments/_admin/age-key.txt
sops secrets/common.yaml
```

Full details (per-host `kuze` passwords, the generator scripts, adding a machine,
using secrets in modules) → **[docs/secrets.md](docs/secrets.md)**.

## Server Roles

Composable infrastructure roles live in `modules/roles/` (ad-dc, radius,
file-server, dns-forwarder, dhcp, print-server, backup, rdp-session-host). They're
not deployed as VMs by default — compose them onto a host when needed. Reference +
per-role config → **[docs/roles.md](docs/roles.md)**. The two domain controllers
*are* deployed: `svgmdl-sada-01` (Samba AD, via `modules/services/samba-ad`) and
`svgmdl-fipa-01` (FreeIPA) — see [Service Hosts](#service-hosts).

## Running Your Own Services (Docker → Nix)

Instead of `docker compose up` + a hand-edited `.env`, services are **declared
in Nix** and run as managed systemd units (logs in journald, restart-on-boot,
started in dependency order). See `hosts/mdl-server/containers.nix` for a
fully-commented, copy-paste template. "OCI" just means the standard container
format Docker and Podman share — an OCI container *is* a Docker container.

How a `docker-compose.yml` maps over:

| docker / compose         | NixIT (declared in Nix)                                          |
|--------------------------|------------------------------------------------------------------|
| `image:` (`:latest`)     | `oci-containers.containers.<name>.image` — **pin the tag**       |
| `.env` file              | a **sops** secret → `environmentFiles` (never committed to git)  |
| `ports:`                 | `ports = [ "127.0.0.1:8080:8080" ]` (bind localhost, proxy in front) |
| `volumes:`               | `volumes = [ "/srv/app:/data" ]`                                 |
| `depends_on:`            | `dependsOn = [ "db" ]`                                           |
| compose default network  | a one-line systemd oneshot + `extraOptions = [ "--network=appnet" ]` |
| `restart: always`        | automatic — it's a systemd service                               |

Secrets stay out of git. Put your `.env` contents under a key in an encrypted
sops file and reference the decrypted path:

```nix
{ config, ... }: {
  sops.secrets."myapp/env".sopsFile = ../../secrets/mdl-server.yaml;

  virtualisation.oci-containers.containers.myapp = {
    image = "ghcr.io/example/myapp:1.8.0";        # pinned
    environmentFiles = [ config.sops.secrets."myapp/env".path ];
    ports = [ "127.0.0.1:8080:8080" ];
    volumes = [ "/srv/myapp:/data" ];
  };
}
```

`deploy .#mdl-server` and the container is live. To build your **own** image
from source with no Dockerfile (fully reproducible), use
`pkgs.dockerTools.buildLayeredImage`. For large multi-service stacks with real
Podman networks/pods and auto-update, add [`quadlet-nix`](https://github.com/SEIAROTg/quadlet-nix)
or [`arion`](https://github.com/hercules-ci/arion).

## Service Hosts

Five single-purpose servers, each one line in `flake.nix`. The shared base
(`hosts/_common/server-host.nix`) supplies disk, admin user, and network, so a
host *is* just a name + a service module:

Each runs in its own NixOS VM, named `svgmdl-<4char>-01` (server-guest, `mdl`
cluster). VMs live on `doa.lan`; **auth is at `mdl.auth.li`** and **user-facing
apps are reverse-proxied subdomains of `lua.li`**.

| Host (VM) | Service | Public URL | How it's deployed | Auth |
|-----------|---------|------------|-------------------|------|
| `svgmdl-keyc-01` | Keycloak + Postgres | `mdl.auth.li`       | Docker (`modules/services/keycloak.nix`) | the IdP itself |
| `svgmdl-forg-01` | Forgejo git server  | `git.lua.li`        | native `services.forgejo` | OIDC → Keycloak |
| `svgmdl-outl-01` | Outline docs        | `docs.lua.li`       | native `services.outline` | OIDC → Keycloak |
| `svgmdl-pape-01` | Paperless-ngx       | `paper.lua.li`      | native `services.paperless` | local admin |
| `svgmdl-kasm-01` | Kasm Workspaces     | `office.lua.li`     | Docker host + runbook | OIDC → Keycloak |
| `svgmdl-immi-01` | Immich (photos)     | `photos.lua.li`     | native `services.immich` | OIDC (admin UI) |
| `svgmdl-head-01` | Headscale (VPN ctl) | `vpn.lua.li`        | native `services.headscale` | OIDC (declarative) |
| `svgmdl-exca-01` | ExcaliDash          | `draw.lua.li`       | oci-containers (×2) | OIDC → Keycloak |
| `svgmdl-alia-01` | AliasVault          | `vault.lua.li`      | oci-container (+SMTP) | own auth |
| `svgmdl-game-01` | Pelican (game panel)| `game.lua.li`       | oci-containers + runbook | own auth |
| `svgmdl-mood-01` | moodleng (your app) | TBD                 | oci-containers (app + postgres + collabora) | your app |
| `svgmdl-rumi-01` | rumi (your app)     | TBD                 | oci-containers (mgmt server + postgres) | your app |
| `svgmdl-fipa-01` | FreeIPA DC          | LAN                 | containerized appliance | own + ext OIDC (`ipa idp-add`) |
| `svgmdl-sada-01` | Samba AD DC         | LAN                 | native (roles/ad-dc) | AD; IdP via LDAP federation |

> **Why native modules, not Docker, for three of them?** They ship first-class
> NixOS modules — config + secrets live in `.nix`, the DB is provisioned for
> you, updates ride `nixos-rebuild`. That's *more* managed-through-Nix than a
> container. Keycloak stays on Docker (your call + easy Keycloakify theme mount);
> Kasm has no clean declarative path so it's a prepared host + runbook.

### Before deploying

1. **Domains** (`hosts/_common/server-host.nix`): `internalDomain = doa.lan` (VM
   FQDNs), `serviceDomain = lua.li` (app subdomains), `authUrl = https://mdl.auth.li`
   (Keycloak / OIDC issuer), `realm = main`. Public `.li` domains can use real ACME
   certs at the reverse proxy; `doa.lan` is internal only.
2. **Set each disk** — `nixit.diskDevice` per host in `flake.nix` if a VM isn't on
   `/dev/sda` (e.g. `mkAppServer { name = "svgmdl-forg-01"; device = "/dev/vda"; … }`).
3. **Create the secrets** in `sops secrets/common.yaml` — full key list +
   generator commands are in [`secrets/common.yaml.example`](secrets/common.yaml.example):
   `kuze/password`, `keycloak/env`, `outline/*`, `paperless/admin-password`,
   `kasm/admin-password`, and `newt/<hostname>` per VM.
4. **Ingress/TLS via Pangolin** — every app VM runs a `newt` agent (in the shared
   base) that dials out to your Pangolin, so nothing is exposed directly and
   Pangolin terminates TLS for `mdl.auth.li` / `*.lua.li`. Create one Pangolin
   **site per VM**, put its `PANGOLIN_ENDPOINT` / `NEWT_ID` / `NEWT_SECRET` in the
   `newt/<hostname>` sops secret. (Keycloak stays bound to localhost — newt on the
   same host reaches it.)

Then per host: `./scripts/install-host.sh <host> root@<ip>` once, `deploy .#<host>` after.

### OIDC setup (mostly automated)

The `main` realm and the `forgejo` / `outline` / `kasm` OIDC clients are
**auto-created** on Keycloak's first boot — `modules/services/keycloak-realm.json`
is imported via `--import-realm`, with client secrets injected from the
`keycloak/env` placeholders (`FORGEJO_CLIENT_SECRET`, etc.). You only:

1. Set those `*_CLIENT_SECRET`s in `keycloak/env` (and the matching
   `outline/oidc-client-secret`) — pick any random strings, keep the pairs equal.
2. Finish the runtime-only bits:
   - **Outline** — nothing; fully declarative.
   - **Forgejo** — add the login source once (command in `modules/services/forgejo.nix`).
   - **Kasm** — point OpenID at `https://mdl.auth.li/realms/main` + map groups in its UI.

**Keycloakify themes:** build your theme jar in your Keycloakify project, drop it
in `/srv/keycloak/providers/` on the keycloak host, restart the container, and
select the theme in the realm's Login settings.

## Desktop Environments

All DEs share the same base (`modules/desktop/`) which provides PipeWire audio, Bluetooth, graphics drivers, Thunar file manager, polkit, NetworkManager, and printing.

The `desktopEnvironment` variable in `home-manager.extraSpecialArgs` controls which DE's home-manager config gets imported. The installer sets this automatically.

### Theming

Hyprland runs the **Caelestia QuickShell rice** (bar, notifications, launcher, OSD,
dashboard, wallpaper) via the official `caelestia-shell` flake. GNOME and KDE use
Catppuccin Mocha with Papirus icons and Bibata cursors (GNOME's keyboard layout is
pinned to `ch+de` via dconf). See [docs/desktops.md](docs/desktops.md).

## Shell Aliases

Available on all machines:

| Alias | Command |
|-------|---------|
| `nix-rebuild` | `sudo nixos-rebuild switch --flake /etc/nixos` |
| `nix-update` | Update flake inputs + rebuild |
| `nix-prune` | Clean old generations + garbage collect |
| `nix-gens` | List generations |
| `space-scan` | Disk usage scan (excludes Docker volumes) |

## Security

- **nftables** firewall on all machines (modern iptables replacement)
- **SSH** hardened: key-only auth, no root login, rate limited (4/min per IP)
- **fail2ban** on all servers with progressive banning
- **auditd** enabled with exec/permission/identity tracking
- **sysctl** hardened: kptr_restrict, dmesg_restrict, BPF restrictions, network hardening
- **Kernel**: protected image, disabled kexec, blacklisted dangerous modules
- **Core dumps** disabled, PAM login limits enforced
- **Secrets** encrypted at rest (sops-nix), decrypted only at activation time

## Updating

Updates are **pushed intentionally**, not pulled-and-rebooted unattended:

```bash
nix flake update                                   # bump inputs in git
nix flake check                                    # confirm every host builds
nix run github:serokell/deploy-rs -- .#mdl-server  # deploy (auto-rollback on failure)
```

Host-side `system.autoUpgrade` is disabled by default (it was a weekly no-op
unless the lock changed, plus an unattended-reboot risk). Flip it on per host
if you prefer a pull model.

## Troubleshooting

### Installation

- nixos-anywhere prints a full log; rerun with `--debug` for more detail
- Validate the disk layout safely first: `nixos-anywhere --vm-test --flake .#<host>`
- If install fails mid-way, check network connectivity from the target — it needs to download packages

### AD Domain Controller

- `samba-tool testparm` — verify Samba config syntax
- `samba-tool user list` — verify domain users exist
- `journalctl -u samba-dc` — Samba DC service logs
- `kinit Administrator` — test Kerberos authentication
- `dig @localhost _ldap._tcp.yourcompany.lan SRV` — test DNS SRV records

### step-ca (Internal CA)

- `step ca health` — check CA status
- CA must be initialized before first use: `step ca init`
- Certificates: `/var/lib/step-ca/certs/`

### General

- `systemctl status <service>` — check any service
- `journalctl -u <service> -f` — follow service logs
- `nixos-rebuild switch --flake /etc/nixos --show-trace` — debug build errors

## License

MIT
