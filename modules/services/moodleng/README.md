# svgmdl-mood-01 — moodleng (your app)

Converted from `MoodleNG/compose.yaml`. Three containers on the private network
`moodlengnet`:
- `moodleng` — the app (one image: nginx + Next.js frontend + Rust backend),
  `ghcr.io/mydrift-user/moodleng:latest`, serves on `:80` → host `127.0.0.1:3033`.
- `moodleng-db` — PostgreSQL 17.
- `collabora` — Collabora Online (document editing via WOPI).

Public registry, no pull auth. Ingress deferred (newt disabled).

## Deploy
1. Secrets in `sops secrets/common.yaml`:
   - `moodleng/db-env` → `POSTGRES_PASSWORD=…`
   - `moodleng/app-env` → `DATABASE_URL=…` (same pw), `JWT_SECRET=…`, `OPENAI_API_KEY=…`
2. Edit `default.nix`: `MOODLE_URL` (your Moodle instance) and `FRONTEND_URL`
   (this app's public URL) — both required.
3. `./scripts/install-host.sh svgmdl-mood-01 root@<ip>` → `deploy .#svgmdl-mood-01`.

## Notes
- AI features need `OPENAI_API_KEY` (optionally `OPENAI_BASE_URL` / `OPENAI_MODEL`
  — add them to `app-env` and the module if you use a non-OpenAI endpoint).
- Image name `ghcr.io/mydrift-user/moodleng` is inferred from the repo — **verify**
  it matches your published package; pin a tag instead of `:latest` for prod.
- `docker logs moodleng` / `moodleng-db` / `collabora`.

## Ingress (when ready)
Set `nixit.newt.enable = true` + a `newt/svgmdl-mood-01` secret and route
`learn.lua.li` (== `FRONTEND_URL`) via Pangolin; or bind `0.0.0.0` + open firewall.
