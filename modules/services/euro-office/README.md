# Euro-Office

EU-sovereign document server (a fork of the ONLYOFFICE Document Server) that
backs Rumi's office document preview and editing.

- Host: `svgmdl-eoff-01`, VMID 218, `10.10.20.24`, engine on port 8085.
- Image is pinned by digest. The registry publishes `:latest` but no version
  tags, so a tag cannot be pinned.
- `JWT_SECRET` (sops `euro-office/env`) must equal `RUMI__DOCUMENTS__JWT_SECRET`
  on the Rumi VM. The engine answers an unsigned request with error `-8`.

## Two paths, both required

The browser loads the editor bundle from the public URL, and rumi-server
fetches the saved document back over the LAN. `RUMI__DOCUMENTS__ENGINE_URL` is
the former, `RUMI__DOCUMENTS__ENGINE_INTERNAL_URL` the latter.

## Do not mount a volume over the log tree

`/var/log/euro-office/documentserver` ships per-service subdirectories.
Mounting an empty volume there hides them and supervisor refuses to start with
`the directory named as part of the path .../adminpanel/out.log does not exist`.
Only the data tree is persisted; container stdout goes to journald.

## Publishing it

The Pangolin site for this host exists (`svgmdl-eoff-01`, created 2026-08-02);
its credentials live in sops under `newt/svgmdl-eoff-01`. The dashboard is
TOTP-gated, so creating another site needs the owner. The `edit.lua.li`
resource is declared here and served through the tunnel.
