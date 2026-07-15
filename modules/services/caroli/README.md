# caroli — Maler Caroli marketing site

Static single-page site (Vite → nginx) for **malercaroli.lua.li**. Public — no
Pangolin SSO. Runs as a container on `svgmdl-caro-01` (`10.10.20.19`), fronted by
newt like every other app VM.

- **Host:** `svgmdl-caro-01` · VLAN 20 · `10.10.20.19/24`
- **Image:** `ghcr.io/mydrift-user/malercaroli:1.0.0` (published from the caroli repo)
- **Local port:** `127.0.0.1:8080` → container `:80`
- **Public URL:** `https://malercaroli.lua.li` (Pangolin resource `caroli`, `sso = false`)
- **Health check:** `GET /` → 200

## Publish the image

The site lives in the `caroli` repo (multi-stage `Dockerfile`, Vite → nginx).
Build and push the tag this module pins:

```bash
# from the caroli repo root
docker build -t ghcr.io/mydrift-user/malercaroli:1.0.0 .
docker push ghcr.io/mydrift-user/malercaroli:1.0.0
```

To wire up the Supabase-backed Referenzen editor, bake the public values in at
build time (they ship in the client bundle anyway; RLS is the real guard):

```bash
docker build -t ghcr.io/mydrift-user/malercaroli:1.0.0 \
  --build-arg VITE_SUPABASE_URL=https://xxxx.supabase.co \
  --build-arg VITE_SUPABASE_ANON_KEY=eyJ... .
```

Bump the tag in `default.nix` when you publish a new version, then `deploy`.

## Bring the VM up (one-time)

Same flow as the rest of the fleet ([DEPLOY.md](../../../DEPLOY.md)):

1. **Pangolin site** — create a site for `svgmdl-caro-01` in Pangolin; put its
   newt credentials in the sops secret `newt/svgmdl-caro-01` (in `common.yaml`).
2. **DNS** — point `malercaroli.lua.li` at the Pangolin ingress (same as the other
   `*.lua.li` records).
3. **Secrets key** — add the host's age key to `.sops.yaml` and `sops updatekeys`
   (its SSH host key is pre-generated in `../mdl-infra/deployments/svgmdl-caro-01/`).
4. **Proxmox VM** — create the guest (2 vCPU / 2 GB / ~20 GB is plenty for a
   static site), NIC `tag=20`, boot the NixOS installer, give it `10.10.20.19/24`.
5. **Install + deploy:**
   ```bash
   ./scripts/install-host.sh svgmdl-caro-01 root@10.10.20.19
   nix run github:serokell/deploy-rs -- .#svgmdl-caro-01
   ```

Once up, the blueprint auto-registers the `caroli` resource and the site answers
at `https://malercaroli.lua.li`.
