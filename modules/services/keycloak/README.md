# svgmdl-keyc-01 — Keycloak (OIDC identity provider)

The fleet's IdP. Docker: Keycloak + Postgres, with the realm and OIDC clients
auto-imported on first boot. Public URL: `mdl.auth.li` (via Pangolin → newt →
`127.0.0.1:8080` on this host).

## Deploy
1. Secrets in `sops secrets/common.yaml` (template: `secrets/common.yaml.example`):
   - `keycloak/env` — `POSTGRES_PASSWORD`, `KC_DB_PASSWORD` (=same), `KEYCLOAK_ADMIN`,
     `KEYCLOAK_ADMIN_PASSWORD`, and `FORGEJO_/OUTLINE_/KASM_CLIENT_SECRET`.
   - `newt/svgmdl-keyc-01` — Pangolin tunnel creds.
2. `./scripts/install-host.sh svgmdl-keyc-01 root@<ip>`
3. `nix run github:serokell/deploy-rs -- .#svgmdl-keyc-01`

## What's automated
`cmd = ["start" "--import-realm"]` loads `keycloak-realm.json`: realm `main` +
clients `forgejo` / `outline` / `kasm` with their redirect URIs and secrets pulled
from the `*_CLIENT_SECRET` env placeholders. Verify by logging in to
`https://mdl.auth.li` with the admin creds.

> Import only runs when the realm is absent. Make later changes in the UI (or
> delete the realm to re-import).

## Keycloakify custom login pages
1. Build the theme jar in your Keycloakify project (`npm run build-keycloak-theme`).
2. `scp target/*.jar root@<ip>:/srv/keycloak/providers/`
3. `ssh root@<ip> 'docker restart keycloak'`
4. Realm settings → Themes → Login theme → select yours.

## Add an OIDC client for a new app
Edit `keycloak-realm.json` (new client + redirect URI + `${NEWAPP_CLIENT_SECRET}`),
add that secret to `keycloak/env`, `deploy`. On an already-running Keycloak, add
it in the UI (Clients → Create) instead.

## Troubleshoot
- `docker logs keycloak` / `docker logs keycloak-db`
- Placeholder not substituted by your KC build → set the secret in
  Clients → <app> → Credentials.
