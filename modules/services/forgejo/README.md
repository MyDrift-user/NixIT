# svgmdl-forg-01 — Forgejo (git server)

Native `services.forgejo` with a local Postgres (socket/peer auth — no DB
password). Public URL: `git.lua.li`.

## Deploy
1. Secret: `newt/svgmdl-forg-01` (Pangolin). No service secret needed.
2. `./scripts/install-host.sh svgmdl-forg-01 root@<ip>` → `deploy .#svgmdl-forg-01`.

## OIDC login via Keycloak (one-time, runtime)
Self-registration is off; accounts come from Keycloak (the `forgejo` client is
auto-created there). Add the login source once:

```
ssh root@<ip>
sudo -u forgejo forgejo --config /var/lib/forgejo/custom/conf/app.ini \
  admin auth add-oauth \
  --name keycloak --provider openidConnect --key forgejo \
  --secret <FORGEJO_CLIENT_SECRET from keycloak/env> \
  --auto-discover-url https://mdl.auth.li/realms/main/.well-known/openid-configuration
```

First admin: `sudo -u forgejo forgejo admin user create --admin …`, or let the
first Keycloak user log in and promote them.

## Common config (edit `default.nix` → deploy)
- `settings.service.DISABLE_REGISTRATION` (true), `repository.DEFAULT_PRIVATE`
  (private), `lfs.enable` (on). Larger pushes → `settings.server.*`.

## Troubleshoot
- `journalctl -u forgejo -f` · `systemctl status forgejo`
- DB: `sudo -u postgres psql forgejo`
