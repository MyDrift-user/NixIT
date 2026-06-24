# svgmdl-alia-01 — AliasVault (password manager + email aliases)

Single oci-container (`ghcr.io/aliasvault/aliasvault`) bundling client/api/admin
+ an SMTP server. Web UI behind Pangolin at `vault.lua.li`; SMTP exposed directly
to receive alias mail. Has its own auth (no Keycloak OIDC).

## Deploy
1. Secret: `newt/svgmdl-alia-01` (Pangolin). App keys are auto-generated.
2. Set `PRIVATE_EMAIL_DOMAINS` in `default.nix` to your alias mail domain(s).
3. `./scripts/install-host.sh svgmdl-alia-01 root@<ip>` → `deploy .#svgmdl-alia-01`.

## DNS / mail (required for aliasing)
- `vault.lua.li` → Pangolin (web UI).
- **MX record** for your alias domain → this host's public IP (SMTP on 25/587 is
  open in the firewall). Add SPF/DMARC for deliverability.

## First login
The admin password is generated on first start — read it:
```
ssh root@<ip> 'cat /srv/aliasvault/secrets/* 2>/dev/null | grep -i admin'   # or check `docker logs aliasvault`
```
Then log in at `https://vault.lua.li/admin`.

## Notes
- All state in `/srv/aliasvault/{database,secrets,logs,certificates}` — back it up.
- Pin the `:latest` tag once you settle on a version.
- Mobile apps need a publicly trusted cert (Pangolin's ACME cert is fine; a
  self-signed one is rejected).
