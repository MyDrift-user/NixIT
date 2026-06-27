# Keycloak (OIDC identity provider) — Docker, as requested.
# Keycloak + Postgres on a private network; the Keycloakify theme jar drops into
# a mounted providers dir. This is the IdP the other hosts authenticate against.
#
# Realm + OIDC clients (forgejo/outline/kasm) are auto-created from
# keycloak-realm.json via --import-realm on first boot; client secrets come from
# the env file as ${...} placeholders. (Realm import runs once; later changes are
# made in the UI. If your Keycloak build doesn't substitute the placeholders, set
# the client secrets in the UI instead.)
#
# Secret (sops secrets/common.yaml, key `keycloak/env`) — an env file:
#   POSTGRES_PASSWORD=<db pw>
#   KC_DB_PASSWORD=<same db pw>
#   KEYCLOAK_ADMIN=admin
#   KEYCLOAK_ADMIN_PASSWORD=<bootstrap admin pw>
#   FORGEJO_CLIENT_SECRET / OUTLINE_CLIENT_SECRET / KASM_CLIENT_SECRET=<per-app>
{ config, ... }:
let
  net = "keycloak";
  docker = "${config.virtualisation.docker.package}/bin/docker";
in {
  sops.secrets."keycloak/env".sopsFile = ../../../secrets/common.yaml;

  systemd.services.init-keycloak-net = {
    description = "create keycloak docker network";
    after = [ "docker.service" "docker.socket" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = "${docker} network inspect ${net} >/dev/null 2>&1 || ${docker} network create ${net}";
  };

  virtualisation.oci-containers.containers = {
    keycloak-db = {
      image = "postgres:16.4-alpine";
      volumes = [ "/srv/keycloak/db:/var/lib/postgresql/data" ];
      environment = { POSTGRES_DB = "keycloak"; POSTGRES_USER = "keycloak"; };
      environmentFiles = [ config.sops.secrets."keycloak/env".path ];
      extraOptions = [ "--network=${net}" ];
    };
    keycloak = {
      image = "quay.io/keycloak/keycloak:26.0";
      dependsOn = [ "keycloak-db" ];
      # Build the optimized image once, then exec the server. The stock image's
      # auto-build-on-`start` was looping (build → exit → systemd restart, 100s of
      # times) and never serving; `build && exec start --optimized` keeps the
      # server process as PID 1 so it stays up.
      cmd = [ "sh" "-c" "/opt/keycloak/bin/kc.sh build && exec /opt/keycloak/bin/kc.sh start --optimized --import-realm" ];
      environment = {
        KC_DB             = "postgres";
        KC_DB_URL_HOST    = "keycloak-db";
        KC_DB_USERNAME    = "keycloak";
        KC_HOSTNAME       = config.nixit.authUrl;   # https://mdl.auth.li
        KC_PROXY_HEADERS  = "xforwarded";   # behind a TLS reverse proxy
        KC_HTTP_ENABLED   = "true";
        KC_HEALTH_ENABLED = "true";
      };
      environmentFiles = [ config.sops.secrets."keycloak/env".path ];
      ports = [ "127.0.0.1:8080:8080" ];     # reached by newt (Pangolin) on this host
      volumes = [
        "/srv/keycloak/providers:/opt/keycloak/providers"               # Keycloakify jar goes here
        "${./keycloak-realm.json}:/opt/keycloak/data/import/main-realm.json:ro"
      ];
      extraOptions = [ "--network=${net}" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/keycloak 0750 root root -"
    "d /srv/keycloak/db 0750 root root -"
    "d /srv/keycloak/providers 0755 root root -"
  ];
}
