# svgmdl-sada-01 — Samba Active Directory domain controller

AD DC (Samba) + Kerberos + internal DNS + Chrony NTP + step-ca, via
`modules/roles/ad-dc`. Realm `AD.DOA.LAN`, NetBIOS domain `AD`, DC `SADA01`.

> DCs need a **static IP** (clients point DNS here) — set one in the host network
> config before enrolling clients.

## Deploy
1. Secrets in `sops secrets/ad-dc.yaml` (this host is in its key group):
   `ad/admin-password` and `ca/intermediate-password`. Plus `kuze/password` in
   common.yaml (handled by the base).
2. `./scripts/install-host.sh svgmdl-sada-01 root@<ip>` → `deploy .#svgmdl-sada-01`.

## Provision the domain (once, after first boot)
```
sudo bash /etc/nixos/modules/roles/ad-dc/provision.sh \
  --realm=AD.DOA.LAN --domain=AD --admin-pass='<StrongPass!>'
samba-tool domain level show          # verify
kinit Administrator                    # test Kerberos
```

## Best-practice accounts
```
# Example user
samba-tool user create jdoe '<UserPass!>' --given-name=John --surname=Doe
# Root-equivalent: add to Domain Admins (full control of the domain)
samba-tool group addmembers "Domain Admins" jdoe
# Keep the built-in Administrator as break-glass; do daily work as a named admin.
samba-tool user list
```
Domain-joined machines then honour `AD\Domain Admins` for local admin/sudo
(via SSSD/winbind on Linux, or GPO on Windows).

## OIDC (connect to an IdP — when ready)
Samba AD is not itself an OIDC provider. The standard pattern is to point an IdP
at it: in Keycloak (`svgmdl-keyc-01`) add **User Federation → LDAP/Kerberos**
against `ldaps://svgmdl-sada-01:636` (bind as a service account), then apps use
Keycloak OIDC while identities live in AD. (For Windows-side federation use
AD FS / Entra Connect separately.)
