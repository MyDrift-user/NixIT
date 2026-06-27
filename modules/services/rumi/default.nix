# rumi — MSP platform (github.com/mydrift-user/rumi). Single-VM deployment of:
#   MGMT instance  (rumi.lua.li)            : rumi-server + rumi-db
#   CUSTOMER inst. (service.wdconsulting.ch): customer-server + customer-db (federated)
#
# Images are BUILT ON THIS VM from the repo staged at /opt/rumi (Dockerfile,
# Dockerfile.customer — each bundles the Next.js web into the Rust binary, one
# port each). The `rumi-build` oneshot builds them (idempotent: skips if the
# image already exists; `systemctl restart rumi-build` to force a rebuild). All
# containers share one docker network so the MSP reaches the customer instance
# for federation. Ingress is the external Pangolin/Traefik (via the host's newt
# tunnel) — no TLS terminator here.
#
# MESH (headscale) is intentionally NOT deployed: Pangolin/Traefik already
# terminates TLS for the web, and headscale's device-facing control plane + DERP
# need their own wiring. To add it later: run the headscale container and front
# it with a Pangolin TCP/UDP resource (control HTTP + udp/3478 DERP-STUN) — do
# NOT re-introduce caddy. The server's mesh module idles as "not configured".
#
# MGMT auth = OIDC against the existing Keycloak (mdl.auth.li, client `rumi`).
# CUSTOMER auth = its own host-admin login + email codes, fenced behind Pangolin.
#
# Secrets (sops secrets/common.yaml): rumi/{db-env,server-env,customer-db-env,customer-env}
{ config, pkgs, ... }:
let
  net = "ruminet";
  repo = "/opt/rumi";                                   # repo staged here (deploy-time)
  docker = "${config.virtualisation.docker.package}/bin/docker";
  cfg = config.nixit;
  mgmtUrl = "https://rumi.${cfg.serviceDomain}";          # rumi.lua.li
  custUrl = "https://service.wdconsulting.ch";
in {
  sops.secrets."rumi/db-env".sopsFile          = ../../../secrets/common.yaml;
  sops.secrets."rumi/server-env".sopsFile      = ../../../secrets/common.yaml;
  sops.secrets."rumi/customer-db-env".sopsFile = ../../../secrets/common.yaml;
  sops.secrets."rumi/customer-env".sopsFile    = ../../../secrets/common.yaml;

  # one shared network so the MSP federation proxy reaches customer-server by name
  systemd.services.init-rumi-net = {
    description = "create rumi docker network";
    after = [ "docker.service" "docker.socket" ]; requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = "${docker} network inspect ${net} >/dev/null 2>&1 || ${docker} network create ${net}";
  };

  # Build the two images from the staged repo. Idempotent; force with
  # `systemctl restart rumi-build` after pulling repo changes (BuildKit cache).
  systemd.services.rumi-build = {
    description = "build rumi server + customer images from ${repo}";
    after = [ "docker.service" ]; requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.virtualisation.docker.package pkgs.git ];
    environment.DOCKER_BUILDKIT = "1";
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; TimeoutStartSec = "3600"; };
    script = ''
      set -eu
      [ -f ${repo}/Dockerfile ] || { echo "repo not staged at ${repo}; skipping build"; exit 0; }
      ${docker} image inspect rumi-server:local   >/dev/null 2>&1 || ${docker} build -t rumi-server:local   -f ${repo}/Dockerfile          ${repo}
      ${docker} image inspect rumi-customer:local >/dev/null 2>&1 || ${docker} build -t rumi-customer:local -f ${repo}/Dockerfile.customer ${repo}
    '';
  };

  virtualisation.oci-containers.containers = {
    # ── MGMT stack ──────────────────────────────────────────────────────
    rumi-db = {
      image = "postgres:18-alpine";
      cmd = [ "postgres" "-c" "shared_preload_libraries=pg_stat_statements" "-c" "pg_stat_statements.track=all" "-c" "max_connections=200" ];
      environment = { POSTGRES_DB = "rumi"; POSTGRES_USER = "rumi"; };
      environmentFiles = [ config.sops.secrets."rumi/db-env".path ];
      volumes = [ "rumi-pgdata:/var/lib/postgresql" ];
      extraOptions = [ "--network=${net}" "--network-alias=rumi-db" ];
    };

    rumi-server = {
      image = "rumi-server:local";                       # built on-VM by rumi-build
      dependsOn = [ "rumi-db" ];
      ports = [ "127.0.0.1:8080:8080" ];                 # reached by newt (Pangolin)
      environment = {
        "RUMI__BIND" = "0.0.0.0:8080";
        RUMI_TRUST_PROXY = "true";
        RUMI_SERVER_URL = mgmtUrl;
        RUMI_PUBLIC_URL = mgmtUrl;
        # The server reads the nested RUMI__AUTH__ISSUER (flat RUMI_ISSUER is
        # ignored). It must be the https URL so the auth handlers use Secure
        # __Host- cookies that match what the OIDC callback sets; otherwise the
        # session cookie is written and read under different names -> "session
        # expired" loop.
        "RUMI__AUTH__ISSUER" = mgmtUrl;
        RUMI_ISSUER     = mgmtUrl;
        "RUMI__DATABASE__POOL_SIZE" = "20";
        RUMI_PACKAGES_LOCAL_PATH = "/var/lib/rumi/packages";
        # The customer instance is co-located on the docker network and only
        # reachable server-to-server at http://customer-server:8090 (its public
        # https URL sits behind Pangolin auth). Allow that internal http target
        # for the federation link; the SSRF guard otherwise blocks private IPs.
        RUMI_ALLOW_INSECURE_FEDERATION = "1";
        RUMI_DEV_INSECURE_PG = "true";                    # bundled PG on the private net (no TLS)
        RUMI_CORS_ORIGINS = mgmtUrl;
        # Management IdP = the existing Keycloak (non-interactive bootstrap).
        "RUMI__MANAGEMENT_SETUP__KIND"         = "oidc";
        "RUMI__MANAGEMENT_SETUP__LABEL"        = "Keycloak";
        "RUMI__MANAGEMENT_SETUP__ADMIN_EMAIL"  = "joel.maurer@mdlab.ch";
        "RUMI__MANAGEMENT_SETUP__ADMIN_DISPLAY_NAME" = "Joel Maurer";
        "RUMI__MANAGEMENT_SETUP__OIDC_ISSUER"    = "${cfg.authUrl}/realms/${cfg.realm}";
        "RUMI__MANAGEMENT_SETUP__OIDC_CLIENT_ID" = "rumi";
        "RUMI__MANAGEMENT_SETUP__OIDC_SCOPES"    = "openid profile email";
        RUST_LOG = "info,rumi_server=info";
      };
      environmentFiles = [ config.sops.secrets."rumi/server-env".path ];  # DB url, JWT, vault key, OIDC secret
      volumes = [ "rumidata:/var/lib/rumi" ];
      extraOptions = [ "--network=${net}" "--network-alias=rumi-server" ];
    };

    # ── CUSTOMER stack (federated to the MSP over ${net}) ───────────────
    customer-db = {
      image = "postgres:18-alpine";
      environment = { POSTGRES_DB = "customer"; POSTGRES_USER = "rumi"; };
      environmentFiles = [ config.sops.secrets."rumi/customer-db-env".path ];
      volumes = [ "customer-pgdata:/var/lib/postgresql" ];
      extraOptions = [ "--network=${net}" "--network-alias=customer-db" ];
    };

    customer-server = {
      image = "rumi-customer:local";                     # built on-VM by rumi-build
      dependsOn = [ "customer-db" ];
      ports = [ "127.0.0.1:8090:8090" ];                 # reached by newt (Pangolin, fenced)
      environment = {
        RUMI_BIND = "0.0.0.0:8090";
        RUMI_PUBLIC_URL = custUrl;
        RUMI_VAULT_MANAGED_TEAMS = "1";
        RUMI_CUSTOMER_MODE = "1";
        RUMI_CUSTOMER_ADMIN_EMAIL = "admin@wdconsulting.ch";
        RUMI_INSTANCE_NAME = "WDC";
        # Single-org deployment: every authenticated user (Entra or local) gets
        # the collaboration modules. bin/vault are already baseline; add activities.
        RUMI_DEFAULT_PERMISSIONS = "activities.read activities.write";
        RUST_LOG = "info,rumi_customer_server=info";
      };
      environmentFiles = [ config.sops.secrets."rumi/customer-env".path ];  # DB url, vault key, admin pw, federation keys
      volumes = [ "customer-data:/var/lib/rumi" ];
      extraOptions = [ "--network=${net}" "--network-alias=customer-server" ];
    };
  };

  # servers wait for the network + the image build, and only start once the repo
  # is staged at ${repo} (else they'd race a missing image on first boot). DBs
  # have no gate so they come up early.
  systemd.services.docker-rumi-server     = { after = [ "rumi-build.service" "init-rumi-net.service" ]; requires = [ "rumi-build.service" ]; unitConfig.ConditionPathExists = "${repo}/Dockerfile"; };
  systemd.services.docker-customer-server = { after = [ "rumi-build.service" "init-rumi-net.service" ]; requires = [ "rumi-build.service" ]; unitConfig.ConditionPathExists = "${repo}/Dockerfile"; };

  # Persistent data is in docker-managed named volumes (rumi-pgdata, rumidata,
  # customer-pgdata, customer-data) so postgres/rumi own their dirs with correct
  # perms — bind mounts under /srv broke postgres 18's /var/lib/postgresql/18.
}
