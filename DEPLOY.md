# NixIT — Deployment Runbook

End-to-end: from a fresh clone to a running fleet. Each VM has a focused README
(linked below) for its service-specific config; this is the spine that ties them
together.

## 0. Concepts (30 seconds)
- **Install** = `disko` (declarative partitioning) + `nixos-anywhere` (over SSH),
  driven by `scripts/install-host.sh`.
- **Update** = `deploy-rs` (push with auto-rollback): `nix run github:serokell/deploy-rs -- .#<host>`.
- **Secrets** = sops-nix. Plaintext source of truth lives **outside** this repo in
  `../mdl-infra/deployments/` (per-host SSH keys + the admin age key + `SECRETS.md`).
  The repo holds only the encrypted `secrets/*.yaml`. See [docs/secrets.md](docs/secrets.md).
- **Naming** = `svg<cluster>-<4char>-<NN>` (svg=guest VM). Cluster `mdl`; the VPN box
  is `svgwdc-svpn-01` (father's network).
- **Ingress** = one external **Pangolin**; app VMs run a `newt` tunnel (sops
  `newt/<host>`). DCs/VPN are LAN-facing (no newt). Domains: services on `*.lua.li`,
  auth at `mdl.auth.li`, internal FQDNs `*.doa.lan`.

## 1. Workstation prereqs
- Nix with flakes (this repo is developed from Ubuntu WSL).
- The admin age key: `export SOPS_AGE_KEY_FILE=../mdl-infra/deployments/_admin/age-key.txt`
  (needed to read/edit secrets). **Back this folder up — it decrypts everything.**

## 2. Secrets — already bootstrapped
Real secrets were generated (`scripts/gen-secrets.sh` + `gen-kuze-pw.sh`) and are
encrypted in `secrets/`. Before deploying, fill the values that can't be
auto-generated (they're `REPLACE` placeholders):

```bash
export SOPS_AGE_KEY_FILE=../mdl-infra/deployments/_admin/age-key.txt
sops secrets/common.yaml      # set: every newt/<host> (Pangolin), fortivpn/config
                              #      (FortiGate), moodleng OPENAI_API_KEY (optional)
```
Everything else (passwords, DB creds, OIDC client secrets, per-host `kuze`
passwords) is already set. The full list with the matching plaintext is in
`../mdl-infra/deployments/SECRETS.md`.

## 3. Install each VM (one-time)
Boot the target into any Linux with SSH (NixOS ISO / this repo's ISO / kexec), set
its disk in `hosts/.../disk.nix` or the host's `nixit.diskDevice` (check `lsblk`),
then:
```bash
./scripts/install-host.sh <host> root@<target-ip>
```
It seeds that host's pre-generated SSH key (from `../mdl-infra/deployments/<host>/`)
so its sops identity matches and first boot decrypts. ⚠️ wipes the target disk.

> DCs (`svgmdl-fipa-01`, `svgmdl-sada-01`) need a **static IP** — set it in the host
> network config before enrolling clients.

## 4. Update (ongoing)
```bash
nix flake update            # bump inputs in git
nix flake check             # confirm every host evaluates
nix run github:serokell/deploy-rs -- .#<host>     # push (auto-rollback)
```

## 5. Per-service one-time config
After a service VM is up, finish its runtime setup (full steps in each README):

| VM | Service | One-time step | README |
|----|---------|---------------|--------|
| `svgmdl-keyc-01` | Keycloak | set OIDC `*_CLIENT_SECRET`s in `keycloak/env`; realm auto-imports | [link](modules/services/keycloak/README.md) |
| `svgmdl-forg-01` | Forgejo | `forgejo admin auth add-oauth …` | [link](modules/services/forgejo/README.md) |
| `svgmdl-outl-01` | Outline | none (declarative OIDC) | [link](modules/services/outline/README.md) |
| `svgmdl-pape-01` | Paperless | set tag/correspondent matching to Auto | [link](modules/services/paperless/README.md) |
| `svgmdl-immi-01` | Immich | OAuth in admin UI | [link](modules/services/immich/README.md) |
| `svgmdl-head-01` | Headscale | declarative OIDC; `headscale users create` | [link](modules/services/headscale/README.md) |
| `svgmdl-exca-01` | ExcaliDash | verify OIDC callback path | [link](modules/services/excalidraw/README.md) |
| `svgmdl-alia-01` | AliasVault | DNS MX → host; read generated admin pw | [link](modules/services/aliasvault/README.md) |
| `svgmdl-kasm-01` | Kasm | `sudo kasm-install <url>` + UI OIDC/shares | [link](modules/services/kasm/README.md) |
| `svgmdl-game-01` | Pelican | create Wings node in panel, paste config | [link](modules/services/pelican/README.md) |
| `svgmdl-mood-01` | moodleng | fill app container from compose | [link](modules/services/moodleng/README.md) |
| `svgmdl-rumi-01` | rumi | fill app env; mesh/glitchtip optional | [link](modules/services/rumi/README.md) |
| `svgmdl-fipa-01` | FreeIPA | install runs on boot; `ipa idp-add` for OIDC | [link](modules/services/freeipa/README.md) |
| `svgmdl-sada-01` | Samba AD | `provision.sh` once | [link](modules/services/samba-ad/README.md) |
| `svgwdc-svpn-01` | FortiGate VPN | fill `fortivpn/config` | [link](modules/services/fortivpn-gateway/README.md) |

Also: create a Pangolin **site per app VM** and put its creds in `newt/<host>`.

## 6. Add a new host
1. `modules/services/<svc>/{default.nix,README.md}` (copy a similar one).
2. One line in `flake.nix` (`mkAppServer …`) + a `deploy.nodes` entry.
3. `scripts/gen-secrets.sh` (or add the host's age key to `.sops.yaml` +
   `sops updatekeys`) — see [docs/secrets.md](docs/secrets.md).
4. `nix flake check` → `install-host.sh` → `deploy`.

## 7. Status / caveats (read before go-live)
- Everything is **eval-validated** (`nix flake check`), not yet **built** — run a
  real `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` on a
  pilot host to catch build-level issues. Pilot one box end-to-end first.
- Container images are pinned by tag but some are `:latest` — pin digests for prod.
- FreeIPA-in-docker (systemd-in-container), Kasm, and Pelican Wings are the
  runtime-fragile ones; verify per their READMEs.
- `moodleng` image name is inferred (`ghcr.io/mydrift-user/moodleng`) — verify.
