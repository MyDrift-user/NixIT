# svgmdl-fipa-01 — FreeIPA domain controller

Identity management DC (LDAP + Kerberos + integrated CA) as the official
containerized appliance. Installs unattended on first boot. Realm `IPA.DOA.LAN`.

> FreeIPA-in-docker runs systemd inside the container — the cgroup mount + tmpfs
> in `default.nix` cover the common case; if the first install fails, that's the
> bit to tune (see freeipa-container docs). DCs want a **static IP** — set one in
> the host's network config (clients/Kerberos depend on stable DNS/host).

## Deploy
1. Secret `freeipa/env` in `sops secrets/common.yaml`: `PASSWORD=<≥8 chars>`
   (sets both `admin` and Directory Manager).
2. `./scripts/install-host.sh svgmdl-fipa-01 root@<ip>` → `deploy .#svgmdl-fipa-01`.
3. First boot runs `ipa-server-install` (a few minutes). Watch: `docker logs -f freeipa`.

## Verify
```
docker exec freeipa kinit admin            # auth as admin
docker exec freeipa ipa user-find
docker exec freeipa ipa ca-show ipa        # internal CA
```

## Best-practice accounts (run once, inside the container)
```
# Example user
docker exec freeipa ipa user-add jdoe --first=John --last=Doe --password
# Admins group already exists; grant full admin (root-equivalent) by membership:
docker exec freeipa ipa group-add-member admins --users=jdoe
# Host sudo: an "all sudo" rule for admins on enrolled hosts
docker exec freeipa ipa sudorule-add admins_all --cmdcat=all --hostcat=all --usercat=all
docker exec freeipa ipa sudorule-add-user admins_all --groups=admins
```
Enrolled Linux clients then get `admin`/`jdoe` logins + passwordless-discovery
sudo via SSSD. (Keep `admin` break-glass; do day-to-day work as a named user.)

## OIDC (connect to an external IdP — when ready)
FreeIPA authenticates users against the existing Keycloak via its **public URL**
`https://mdl.auth.li`. The `freeipa` client (device-flow enabled) is already
created by the Keycloak realm import — use the `FREEIPA_CLIENT_SECRET` from
`keycloak/env`:
```
docker exec freeipa ipa idp-add mdl --provider keycloak \
  --base-url https://mdl.auth.li --org main \
  --client-id freeipa --secret      # paste FREEIPA_CLIENT_SECRET when prompted
docker exec freeipa ipa user-mod jdoe --user-auth-type=idp --idp mdl \
  --idp-user-id jdoe@example.com
```
Other providers also work (`microsoft`/Entra, `google`, `github`, `okta`).
