# svgmdl-head-01 — Headscale (self-hosted Tailscale control)

Native `services.headscale` with **declarative OIDC** against Keycloak. Control
URL: `vpn.lua.li` (Pangolin → newt → `:8080`).

## Deploy
1. Secrets: `headscale/oidc-client-secret` (= `HEADSCALE_CLIENT_SECRET` in
   `keycloak/env`), `newt/svgmdl-head-01`.
2. `./scripts/install-host.sh svgmdl-head-01 root@<ip>` → `deploy .#svgmdl-head-01`.

The `headscale` Keycloak client (redirect `https://vpn.lua.li/oidc/callback`) is
auto-created.

## Use it
On the server (manage the tailnet):
```
headscale users create <you>          # if not using OIDC-created users
headscale preauthkeys create --user <you> --reuse --expiration 24h
headscale nodes list
```
On clients:
```
tailscale up --login-server=https://vpn.lua.li      # OIDC browser login
```

## Notes
- MagicDNS base domain is `ts.doa.lan` (`settings.dns.base_domain`) — the tailnet
  hostname suffix; distinct from `server_url`. Change it in `default.nix` if you like.
- Embedded DERP is off; nodes use Tailscale's DERP relays + P2P. Add a self-hosted
  DERP later if you need it.
- `journalctl -u headscale -f`.
