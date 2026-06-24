# svgmdl-outl-01 — Outline (team docs)

Native `services.outline` with local Postgres + Redis. OIDC against Keycloak is
**fully declarative**. Public URL: `docs.lua.li`.

## Deploy
1. Secrets in `sops secrets/common.yaml`:
   - `outline/secret-key`, `outline/utils-secret` — each `openssl rand -hex 32`.
   - `outline/oidc-client-secret` — must equal `OUTLINE_CLIENT_SECRET` in `keycloak/env`.
   - `newt/svgmdl-outl-01`.
2. `./scripts/install-host.sh svgmdl-outl-01 root@<ip>` → `deploy .#svgmdl-outl-01`.

## OIDC
Nothing to configure — `oidcAuthentication` points at `mdl.auth.li/realms/main`
and the `outline` client is auto-created in Keycloak. The first user to log in
becomes the admin.

> Login failing? The `outline/oidc-client-secret` in sops must match the
> `OUTLINE_CLIENT_SECRET` Keycloak was given.

## Notes
- File storage is local at `/var/lib/outline/data` (change to S3 via
  `services.outline.storage` if you outgrow it).
- `journalctl -u outline -f` to debug.
