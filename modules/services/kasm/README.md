# svgmdl-kasm-01 — Kasm Workspaces

A prepared Docker host. Kasm bootstraps its own DB/certs/admin via an installer,
so it can't be fully declarative — but the host is staged so install is **one
command**. Public URL: `office.lua.li`.

## 1. Deploy the host
1. Secrets: `kasm/admin-password`, `newt/svgmdl-kasm-01`.
2. (optional) set the release URL once in `flake.nix`:
   `mkAppServer { name = "svgmdl-kasm-01"; services = [ … ]; }` then in
   `modules/services/kasm/default.nix` set `nixit.kasm.releaseUrl`. Or pass it below.
3. `./scripts/install-host.sh svgmdl-kasm-01 root@<ip>` → `deploy .#svgmdl-kasm-01`.

## 2. Install Kasm (once)
Copy the current release URL from <https://www.kasmweb.com/downloads> (the file
name carries a build hash), then:

```
ssh root@<ip>
sudo kasm-install https://kasm-static-content.s3.amazonaws.com/kasm_release_<ver>.tar.gz
```

It extracts to `/opt/kasm` and runs the installer with `--accept-eula` and the
admin/user passwords from sops. (The login MOTD repeats these steps.)

## 3. Configure (admin UI at office.lua.li)
- **OIDC** — Access Management → Authentication → OpenID:
  Issuer `https://mdl.auth.li/realms/main`, client `kasm` (id + the
  `KASM_CLIENT_SECRET` you put in `keycloak/env`). Map a Keycloak group/role → a
  Kasm group for auto-provisioning.
- **Default desktop** — Groups → <group> → Settings → Workspaces: assign a
  default image so login lands straight in a desktop.
- **Network shares** — Groups → <group> → Volume Mappings:
  `//fileserver/share` → `/home/kasm-user/share` (CIFS/NFS).
- **Persistent home** — enable Persistent Profile to keep state between sessions.

## Troubleshoot
- `docker ps`; installer help: `sudo bash /opt/kasm/kasm_release/install.sh --help`
- Reinstall: clear `/opt/kasm` and rerun `kasm-install`.
