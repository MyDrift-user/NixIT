# svgmdl-rumi-01 — rumi (your app)

Converted from `rumi/compose.yaml`. Deploys the **MGMT server** on a prepared
PostgreSQL, on the private network `ruminet`:
- `rumi-server` — `ghcr.io/mydrift-user/rumi-server:latest`, serves on `:8080` →
  host `127.0.0.1:8080`.
- `rumi-db` — PostgreSQL 18.

Public registry, no pull auth. Ingress deferred (newt disabled).

## Deploy
1. Secrets in `sops secrets/common.yaml`:
   - `rumi/db-env` → `POSTGRES_PASSWORD=…`
   - `rumi/server-env` → `RUMI__DATABASE__URL=…` (same pw), `RUMI__AUTH__JWT_SECRET=…`
     (≥32 bytes), optional `BOOTSTRAP_EMAIL` / `BOOTSTRAP_PASSWORD`.
2. Edit `default.nix`: `RUMI_SERVER_URL` / `RUMI_PUBLIC_URL` / `RUMI_ISSUER` to the
   externally-reachable URL (must be reachable from enrolled devices/PXE).
3. `./scripts/install-host.sh svgmdl-rumi-01 root@<ip>` → `deploy .#svgmdl-rumi-01`.

The server boots with mesh "not configured" and telemetry off; configure the rest
through its `/setup` wizard.

## Deliberately not wired yet (rumi product subsystems)
rumi's full stack ships only as a build-from-source **dev** compose upstream, so
these are left as follow-ups until there's a prod compose + a decided prod shape:
- **headscale** (device mesh) + its config + the docker-socket reload hook
- **glitchtip** telemetry (db/redis/migrate/web/worker)
- **caddy** TLS terminator for agents
- **rumi-customer-server** — federated per-customer instance (own DB), see
  `rumi/compose.customer.yaml`

When you're ready (or rumi goes public with a prod compose), send it and I'll wire
whichever of these you want — the postgres + server core is already in place.

## Notes
- `RUMI_DEV_INSECURE_PG=true` is set because the co-located Postgres has no TLS
  (same as upstream's bundled stack). Don't point rumi at a TLS-less PG over an
  untrusted network.
- `docker logs rumi-server` / `rumi-db`.
