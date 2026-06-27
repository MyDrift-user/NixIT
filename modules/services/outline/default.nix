# Outline — ported to OCI Docker (outlinewiki/outline + postgres + redis from
# Docker Hub). Faster to iterate than the native build-from-source module.
# Secrets (sops secrets/common.yaml): outline/secret-key, outline/utils-secret,
# outline/oidc-client-secret. Postgres is on a private docker net (internal pw).
{ config, lib, ... }:
let
  cfg = config.nixit;
  kc  = "${cfg.authUrl}/realms/${cfg.realm}/protocol/openid-connect";
  net = "outline-net";
  docker = "${config.virtualisation.docker.package}/bin/docker";
  envFile = "/run/outline/outline.env";
in {
  sops.secrets = {
    "outline/secret-key".sopsFile         = ../../../secrets/common.yaml;
    "outline/utils-secret".sopsFile       = ../../../secrets/common.yaml;
    "outline/oidc-client-secret".sopsFile = ../../../secrets/common.yaml;
  };

  # root assembles the env file from sops secrets (container reads it)
  systemd.services.outline-env = {
    wantedBy = [ "multi-user.target" ];
    before   = [ "docker-outline.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      mkdir -p /run/outline; umask 077
      cat > ${envFile} <<EOF
      NODE_ENV=production
      SECRET_KEY=$(cat ${config.sops.secrets."outline/secret-key".path})
      UTILS_SECRET=$(cat ${config.sops.secrets."outline/utils-secret".path})
      DATABASE_URL=postgres://outline:outline@outline-postgres:5432/outline
      PGSSLMODE=disable
      REDIS_URL=redis://outline-redis:6379
      URL=https://docs.${cfg.serviceDomain}
      PORT=3000
      FILE_STORAGE=local
      FILE_STORAGE_LOCAL_ROOT_DIR=/var/lib/outline/data
      FILE_STORAGE_UPLOAD_MAX_SIZE=26214400
      FORCE_HTTPS=false
      OIDC_CLIENT_ID=outline
      OIDC_CLIENT_SECRET=$(cat ${config.sops.secrets."outline/oidc-client-secret".path})
      OIDC_AUTH_URI=${kc}/auth
      OIDC_TOKEN_URI=${kc}/token
      OIDC_USERINFO_URI=${kc}/userinfo
      OIDC_USERNAME_CLAIM=preferred_username
      OIDC_DISPLAY_NAME=Keycloak
      OIDC_SCOPES=openid profile email
      EOF
    '';
  };

  systemd.services.init-outline-net = {
    after = [ "docker.service" ]; requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = "${docker} network inspect ${net} >/dev/null 2>&1 || ${docker} network create ${net}";
  };

  virtualisation.oci-containers.containers = {
    outline-postgres = {
      image = "postgres:16-alpine";
      environment = { POSTGRES_USER = "outline"; POSTGRES_PASSWORD = "outline"; POSTGRES_DB = "outline"; };
      volumes = [ "/var/lib/outline/pg:/var/lib/postgresql/data" ];
      extraOptions = [ "--network=${net}" "--network-alias=outline-postgres" ];
    };
    outline-redis = {
      image = "redis:7-alpine";
      extraOptions = [ "--network=${net}" "--network-alias=outline-redis" ];
    };
    outline = {
      image = "outlinewiki/outline:latest";   # pin a tag in production
      dependsOn = [ "outline-postgres" "outline-redis" ];
      ports = [ "127.0.0.1:3000:3000" ];       # reached by newt (Pangolin)
      environmentFiles = [ envFile ];
      volumes = [ "/var/lib/outline/data:/var/lib/outline/data" ];
      extraOptions = [ "--network=${net}" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/outline 0750 root root -"
    "d /var/lib/outline/data 0777 root root -"
    "d /var/lib/outline/pg 0700 70 70 -"   # postgres (alpine uid 70) owns its data — don't reset to root
  ];

  networking.firewall.allowedTCPPorts = [ 3000 ];
}
