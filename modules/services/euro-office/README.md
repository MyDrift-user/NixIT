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

`newt.enable` is currently false because no Pangolin site exists for this host.
Create the site (dashboard is TOTP-gated), put its credentials in sops under
`newt/svgmdl-eoff-01`, drop the `newt.enable = false` override in `flake.nix`
and redeploy. The Pangolin resource for `edit.lua.li` is already declared here.
