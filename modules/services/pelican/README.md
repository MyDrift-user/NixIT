# svgmdl-game-01 — Pelican (game server panel)

Open-source panel to host Minecraft, Terraria, and ~anything that runs in Docker.
Two containers on this VM: `pelican-panel` (web UI, behind Pangolin at
`game.lua.li`) and `pelican-wings` (the daemon that runs each game server as its
own Docker container here). Pelican uses its own auth — no Keycloak/OIDC.

> Like Kasm, the Wings daemon is configured at runtime (you create a Node in the
> panel and paste its config), so it isn't fully declarative. Pelican's Docker
> deploy is also officially "work in progress" — expect some hands-on.

## 1. Deploy the host
1. Secret: `newt/svgmdl-game-01` (Pangolin). No app secret (APP_KEY auto-generates).
2. `./scripts/install-host.sh svgmdl-game-01 root@<ip>` → `deploy .#svgmdl-game-01`.
3. Pangolin: route `game.lua.li` → this host's newt → `127.0.0.1:8085` (the panel).

## 2. First-run panel setup
```
ssh root@<ip>
docker exec -it pelican-panel php artisan p:environment:setup   # if prompted
docker exec -it pelican-panel php artisan p:user:make           # create your admin
```

## 3. Create the Wings node (the runtime bit)
In the panel UI (`game.lua.li`):
- **Admin → Nodes → Create**: FQDN = this VM's LAN IP (or a `node.lua.li` you
  proxy), daemon port `8080`, SFTP port `2022`. For a LAN-only daemon use scheme
  `http`; to expose the in-browser console remotely, proxy a subdomain through
  Pangolin to `:8080` (TLS) and use `https`.
- Open the node's **Configuration** tab, copy the generated `config.yml` to the
  host, then restart wings:
  ```
  # paste panel config into /etc/pelican/config.yml on the host, then:
  docker restart pelican-wings
  ```
- **Allocations**: add the node's IP + the ports you opened (25500–25600 for
  Minecraft, 7770–7780 for Terraria — see `default.nix`).

## 4. Create a game server
Admin → Servers → Create → pick an **egg** (Minecraft: Paper/Vanilla/Forge;
Terraria), assign CPU/RAM + an allocation. Wings pulls the image and runs it.

## Ports (already opened in `default.nix`)
- `8080` Wings API/console, `2022` SFTP (direct).
- `25500–25600` + `7770–7780` TCP/UDP for the game servers. Widen as needed.

## Troubleshoot
- `docker logs pelican-panel` / `docker logs pelican-wings`
- Wings won't start until `/etc/pelican/config.yml` exists (step 3).
- Wings needs the Docker socket (mounted) — it creates sibling containers for each
  game server on this host's Docker.
