# svgmdl-immi-01 — Immich (photos)

Native `services.immich` — server, machine-learning, Postgres (+vector ext) and
Redis are all provisioned for you. Public URL: `photos.lua.li`.

## Deploy
1. Secret: `newt/svgmdl-immi-01` (Pangolin). No app secret needed.
2. `./scripts/install-host.sh svgmdl-immi-01 root@<ip>` → `deploy .#svgmdl-immi-01`.
3. First run: open `photos.lua.li`, create the admin account.

## Storage
`mediaLocation = /var/lib/immich`. For a real library, attach a data disk and
point `mediaLocation` at it (the `immich` user must own it), then `deploy`.

## OIDC (admin UI — runtime)
Administration → Settings → Authentication → **OAuth**:
- Issuer `https://mdl.auth.li/realms/main`, client `immich`, secret =
  `IMMICH_CLIENT_SECRET` from `keycloak/env`.
- Settings → Server → External Domain = `https://photos.lua.li`.
The `immich` Keycloak client (redirect `https://photos.lua.li/*`) is auto-created.

## Mobile/CLI
App + `immich-cli` point at `https://photos.lua.li`.

## Troubleshoot
- `journalctl -u immich-server -u immich-machine-learning -f`
