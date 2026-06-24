# svgmdl-exca-01 — ExcaliDash (Excalidraw + dashboard)

Self-hosted Excalidraw with a dashboard, live collaboration, persistent storage
and OIDC. Two oci-containers: `excalidash-frontend` (the app) + `excalidash-backend`
(SQLite + API) on a private docker network. Public URL: `draw.lua.li`.

## Deploy
1. Secret `excalidash/env` in `sops secrets/common.yaml`:
   - `JWT_SECRET`, `CSRF_SECRET` — each `openssl rand -hex 32`.
   - `OIDC_CLIENT_SECRET` — must equal `EXCALIDASH_CLIENT_SECRET` in `keycloak/env`.
   Plus `newt/svgmdl-exca-01`.
2. `./scripts/install-host.sh svgmdl-exca-01 root@<ip>` → `deploy .#svgmdl-exca-01`.

## OIDC
`AUTH_MODE=oidc`, issuer `https://mdl.auth.li/realms/main`, client `excalidash`
(auto-created in Keycloak, redirect `https://draw.lua.li/*`).

> Verify the callback path: `OIDC_REDIRECT_URI` is set to
> `…/api/auth/oidc/callback` — adjust in `default.nix` if ExcaliDash uses a
> different path, then `deploy`.

## Notes
- Drawings persist in `/srv/excalidash/data` (SQLite). Back it up.
- Pin the `:latest` image tags once you settle on a version.
- `docker logs excalidash-frontend` / `excalidash-backend`.
