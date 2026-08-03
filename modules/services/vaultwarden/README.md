# Vaultwarden

Self-hosted Bitwarden-compatible password server.

- Host: `svgmdl-vwrd-01`, VMID 225, `10.10.20.25`, server on port 8086.
- Data: `/srv/vaultwarden/data` on the host, bind-mounted to `/data`.
- Image pinned by digest (currently v1.37.1). `:latest` moves on every upstream
  release and this container owns everybody's passwords, so it is never used
  directly.

## Swapping the data folder

Everything Vaultwarden persists is in that one directory: `db.sqlite3` (+ `-wal`
/ `-shm`), `rsa_key.pem`, `attachments/`, `sends/`, `icon_cache/`, `tmp/`.
Migrating an older install is a wholesale directory replacement.

```sh
systemctl stop docker-vaultwarden
mv /srv/vaultwarden/data /srv/vaultwarden/data.bak
# copy the old VM's folder in, e.g.
#   rsync -a root@<old-vm>:/path/to/vaultwarden-data/ /srv/vaultwarden/data/
chown -R root:root /srv/vaultwarden/data
chmod 700 /srv/vaultwarden/data
systemctl start docker-vaultwarden
curl -fsS http://127.0.0.1:8086/alive
```

Stop the unit before copying. SQLite is in WAL mode and a copy taken while the
server is writing can be torn. Copy `db.sqlite3-wal` and `db.sqlite3-shm` along
with `db.sqlite3`, or checkpoint the old database first.

Keep `rsa_key.pem`. It signs the session JWTs; losing it does not lose vault
data but logs every client out.

If the removed directory is not put back, Vaultwarden recreates an empty one on
the next start and the vault will be blank. Verify `/alive` and log in before
deleting `data.bak`. Note that in that case the directory is created by
*docker* (bind-mount source, `root:root 0755`), not by tmpfiles, which only runs
at boot and on activation: this is why the swap procedure re-applies `chmod 700`
by hand rather than relying on the tmpfiles rule.

An older Vaultwarden's database is migrated forward automatically on first
start. There is no downgrade, so the pre-swap copy is the only rollback.

## Ownership

The image sets no `USER`; the server runs as uid 0 and writes root-owned files.
`systemd.tmpfiles.rules` therefore creates `/srv/vaultwarden/data` as
`root:root 0700`. A data folder copied in with different ownership fails only
as opaque 500s once SQLite cannot open the file (this is the same class of bug
that broke euro-office, where the container ran as uid 105).

## ADMIN_TOKEN

sops `vaultwarden/env` holds `ADMIN_TOKEN` as an **Argon2id PHC string**, not
the plaintext. The plaintext is what you type at `/admin`; it is recorded in
`mdl-infra/credentials.md`.

Rotate:

```sh
docker run --rm -it --entrypoint /vaultwarden \
  vaultwarden/server@sha256:<pinned-digest> hash --preset owasp
```

Put the printed `$argon2id$...` value (no surrounding quotes) into
`vaultwarden/env` with `sops set secrets/common.yaml '["vaultwarden"]["env"]'`,
record the new plaintext in `credentials.md`, and redeploy. The secret has
`restartUnits`, so the container restarts on change.

`--env-file` does no variable expansion, so the `$` signs in the PHC string
need no escaping.

## Publishing it

`nixit.newt.enable = false` for now: the Pangolin site for this host does not
exist yet and the dashboard is TOTP-gated, so the owner has to create it. The
`vault.lua.li` resource is already declared here and starts serving as soon as
the site credentials land in sops under `newt/svgmdl-vwrd-01` and newt is
enabled in `flake.nix`.

Until then the server is reachable on the LAN at `http://10.10.20.25:8086`.
`DOMAIN` is already set to `https://vault.lua.li`; it must match whatever URL
clients actually use, or WebAuthn and the send/attachment links break.
