# rumi — your app (github.com/mydrift-user/rumi). Device-management platform.
# This deploys the MGMT server (rumi-server) on a prepared PostgreSQL, with the
# core env to boot. Public registry, no pull auth.
#
# Scope note: rumi's full stack (its own headscale mesh, glitchtip telemetry,
# caddy TLS, and the federated rumi-customer-server) is a larger topology that
# the upstream repo currently only ships as a build-from-source DEV compose.
# Those subsystems are OPTIONAL at boot (mesh = "not configured", telemetry off)
# and are left as documented follow-ups — wire them when a prod compose lands
# and you decide the production shape (see README.md).
#
# Secrets (sops secrets/common.yaml):
#   rumi/db-env      -> POSTGRES_PASSWORD=<pw>
#   rumi/server-env  -> RUMI__DATABASE__URL=postgres://rumi:<pw>@rumi-db:5432/rumi
#                       RUMI__AUTH__JWT_SECRET=<openssl rand -hex 32>   (>=32 bytes, required)
#                       BOOTSTRAP_EMAIL=<you>            # first admin (optional)
#                       BOOTSTRAP_PASSWORD=<pw>
{ config, ... }:
let
  net = "ruminet";
  docker = "${config.virtualisation.docker.package}/bin/docker";
in {
  sops.secrets."rumi/db-env".sopsFile     = ../../../secrets/common.yaml;
  sops.secrets."rumi/server-env".sopsFile = ../../../secrets/common.yaml;

  systemd.services.init-rumi-net = {
    description = "create rumi docker network";
    after = [ "docker.service" "docker.socket" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = "${docker} network inspect ${net} >/dev/null 2>&1 || ${docker} network create ${net}";
  };

  virtualisation.oci-containers.containers = {
    rumi-db = {
      image = "postgres:18-alpine";
      volumes = [ "/srv/rumi/db:/var/lib/postgresql" ];
      environment = { POSTGRES_DB = "rumi"; POSTGRES_USER = "rumi"; };
      environmentFiles = [ config.sops.secrets."rumi/db-env".path ];
      extraOptions = [ "--network=${net}" ];
    };

    rumi-server = {
      image = "ghcr.io/mydrift-user/rumi-server:latest";   # public; pin a tag/sha
      dependsOn = [ "rumi-db" ];
      ports = [ "127.0.0.1:8080:8080" ];        # front with a reverse proxy (ingress TBD)
      environment = {
        # ── EDIT the externally-reachable URLs ──────────────────────────
        RUMI_SERVER_URL = "https://rumi.lua.li";   # device/PXE-facing base
        RUMI_PUBLIC_URL = "https://rumi.lua.li";   # browser/OIDC base
        RUMI_ISSUER     = "https://rumi.lua.li";
        # ── plumbing ────────────────────────────────────────────────────
        "RUMI__BIND" = "0.0.0.0:8080";
        "RUMI__DATABASE__POOL_SIZE" = "20";
        RUMI_TRUST_PROXY = "true";                 # TLS terminated by the proxy
        RUMI_PACKAGES_LOCAL_PATH = "/var/lib/rumi/packages";
        # Co-located Postgres has no TLS (private docker net), same posture as
        # upstream's bundled compose. Do NOT use a TLS-less PG over an untrusted
        # network. See rumi docs/runbooks/tls.md to enable verify-full instead.
        RUMI_DEV_INSECURE_PG = "true";
        RUST_LOG = "info,rumi_server=info";
      };
      environmentFiles = [ config.sops.secrets."rumi/server-env".path ];  # DB url, JWT, bootstrap
      volumes = [ "/srv/rumi/data:/var/lib/rumi" ];
      extraOptions = [ "--network=${net}" ];
    };

    # ── Follow-ups (rumi product subsystems) — add when you pick prod shape ─
    # headscale (mesh)      : ghcr.io/juanfont/headscale:0.28.0 + headscale-config
    # glitchtip (telemetry) : glitchtip-{db,redis,migrate,web,worker} (Sentry-compat)
    # caddy (agent TLS)     : caddy:2-alpine in front of headscale
    # rumi-customer-server  : ghcr.io/mydrift-user/rumi-customer-server (own DB,
    #                         federated to this MSP) — see compose.customer.yaml
  };

  systemd.tmpfiles.rules = [
    "d /srv/rumi 0750 root root -"
    "d /srv/rumi/db 0750 root root -"
    "d /srv/rumi/data 0750 root root -"
  ];
}
