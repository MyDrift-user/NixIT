# _common — shared app-server base

`server-host.nix` is imported by every `mkAppServer` host (the `svgmdl-*` service
VMs). It supplies the disko disk layout, the `kuze` admin user (sops password),
systemd-boot, `networking.domain`, the `nixit.*` options, and the **newt**
Pangolin tunnel container. So each service host is just a name + its service
module.

## nixit options (override per host in `flake.nix`, or fleet-wide here)
| Option | Default | Purpose |
|--------|---------|---------|
| `nixit.internalDomain` | `doa.lan` | VM FQDN suffix (`svgmdl-x-01.doa.lan`) |
| `nixit.serviceDomain`  | `lua.li`  | user-facing app subdomains |
| `nixit.authUrl`        | `https://mdl.auth.li` | Keycloak / OIDC issuer |
| `nixit.realm`          | `main`    | Keycloak realm |
| `nixit.diskDevice`     | `/dev/sda`| disko install target |

## Add a new service VM
1. `modules/services/<svc>/default.nix` (the service) + a `README.md`.
2. `flake.nix`: one line —
   `"svgmdl-<4char>-01" = mkAppServer { name = "svgmdl-<4char>-01"; services = [ ./modules/services/<svc> ]; };`
   and a matching `deploy.nodes."svgmdl-<4char>-01" = mkNode "...";`.
3. Secrets in `secrets/common.yaml` incl. `newt/svgmdl-<4char>-01`; add a Pangolin
   site and its anchor in `.sops.yaml`.
4. `nix flake check` → `./scripts/install-host.sh <host> root@<ip>` → `deploy`.

## Pangolin (newt)
Every app VM runs `fosrl/newt` (host network) dialing your Pangolin — one **site
per VM**, creds in sops `newt/<hostname>`. Nothing is exposed directly; Pangolin
terminates TLS for `mdl.auth.li` and `*.lua.li`.
