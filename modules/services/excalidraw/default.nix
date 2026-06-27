# ExcaliDash — self-hosted Excalidraw + dashboard/organizer with live collab and
# OIDC. Two containers: frontend (serves the app) + backend (SQLite, API).
# Public URL: draw.lua.li.
#
# Secret (sops secrets/common.yaml, key `excalidash/env`):
#   JWT_SECRET=<openssl rand -hex 32>
#   CSRF_SECRET=<openssl rand -hex 32>
#   OIDC_CLIENT_SECRET=<= EXCALIDASH_CLIENT_SECRET in keycloak/env>
{ config, ... }:
let
  cfg = config.nixit;
  net = "excalidash";
  docker = "${config.virtualisation.docker.package}/bin/docker";
  base = "https://draw.${cfg.serviceDomain}";
in {
  sops.secrets."excalidash/env".sopsFile = ../../../secrets/common.yaml;

  systemd.services.init-excalidash-net = {
    description = "create excalidash docker network";
    after = [ "docker.service" "docker.socket" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = "${docker} network inspect ${net} >/dev/null 2>&1 || ${docker} network create ${net}";
  };

  virtualisation.oci-containers.containers = {
    excalidash-backend = {
      image = "zimengxiong/excalidash-backend:latest";   # pin a tag in production
      volumes = [ "/srv/excalidash/data:/app/prisma" ];
      environment = {
        DATABASE_PROVIDER = "sqlite";
        DATABASE_URL = "file:/app/prisma/dev.db";
        NODE_ENV = "production";
        TRUST_PROXY = "true";                 # behind Pangolin
        AUTH_MODE = "oidc_enforced";
        OIDC_PROVIDER_NAME = "Keycloak";
        OIDC_ISSUER_URL = "${cfg.authUrl}/realms/${cfg.realm}";
        OIDC_CLIENT_ID = "excalidash";
        OIDC_REDIRECT_URI = "${base}/api/auth/oidc/callback";  # verify path vs ExcaliDash docs
        FRONTEND_URL = base;
        BACKEND_URL = base;
      };
      environmentFiles = [ config.sops.secrets."excalidash/env".path ];
      extraOptions = [ "--network=${net}" "--network-alias=backend" ];   # frontend nginx upstream is "backend"
    };
    excalidash-frontend = {
      image = "zimengxiong/excalidash-frontend:latest";
      dependsOn = [ "excalidash-backend" ];
      ports = [ "127.0.0.1:6767:80" ];        # reached by newt (Pangolin)
      extraOptions = [ "--network=${net}" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/excalidash 0755 root root -"
    "d /srv/excalidash/data 0777 root root -"
  ];
}
