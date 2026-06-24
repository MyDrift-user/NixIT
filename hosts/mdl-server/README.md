# mdl-server — general Docker host (stable)

Catch-all Docker server. Containers are declared in `containers.nix` via
`virtualisation.oci-containers` (it ships a fully-commented worked example).

## Files
- `disk.nix` (disko), `hardware-configuration.nix`, `network.nix`, `users.nix`,
  `containers.nix`.

## Install / update
- `./scripts/install-host.sh mdl-server root@<ip>`
- `deploy .#mdl-server` (or `nix-rebuild` locally).

## Add a container
Edit `containers.nix` — copy the example: pinned image tag, port bound to
`127.0.0.1`, volume, `environmentFiles` from a sops secret, shared docker network
+ `dependsOn` for multi-container stacks. Then `deploy`.

## Secrets
`kuze/password`, plus a sops env secret per containerized app you add.

> This host predates the `svgmdl-<svc>-01` naming convention. Rename it (and its
> `flake.nix` / `deploy.nodes` / `.sops.yaml` entries) to e.g. `svgmdl-dock-01`
> if you want fleet-wide consistency.
