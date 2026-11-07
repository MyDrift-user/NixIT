# Devolutions Server (the shared backend of Remote Desktop Manager) with its own PostgreSQL,
# LAN only: no newt, no Pangolin resource. https://<host> with the image's self-signed certificate.
#
# Data: /srv/dvls/app_data (encryption.config), /srv/dvls/certs and /srv/dvls/db (PostgreSQL datadir).
# The vault's data cannot be decrypted without encryption.config; a copy is in rumi.
# Secret: sops dvls/env with POSTGRES_PASSWORD=, DATABASE_PASSWORD= (same value) and
# DVLS_ADMIN_PASSWORD= (first logon of dvls-admin only, which then forces a new one).
#
# Update: back up first, then change the image here. Normal starts apply schema upgrades themselves.
{ config, lib, pkgs, ... }:
let
  net = "dvls-net";
  # Pinned by digest like vaultwarden: this container owns passwords and migrates its schema on start.
  image = "devolutions/devolutions-server:2026.3.13.0@sha256:12c05097f4ad5a3e0ffe1d00c0b4855e24369b7e33becaab5a0072e49024a4a3";
  host = "10.20.10.19";
  docker = "${config.virtualisation.docker.package}/bin/docker";
  envFile = config.sops.secrets."dvls/env".path;
  environment = {
    DATABASE_TYPE = "PostgreSQL";
    DATABASE_HOST = "db";
    DATABASE_NAME = "dvls";
    DATABASE_USERNAME = "dvls";
    HOSTNAME = host;
    WEB_SCHEME = "https";
    PORT = "5000";
    EXTERNAL_WEB_SCHEME = "https";
    EXTERNAL_WEB_PORT = "443";
    EXTERNAL_WEB_HOSTNAME = host;
    TLS_CERTIFICATE_FILE = "/opt/devolutions/dvls/certs/server.pem";
    TLS_PRIVATE_KEY_FILE = "/opt/devolutions/dvls/certs/server.key";
  };
  envArgs = lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "-e ${k}=${v}") environment);
  volumes = [ "/srv/dvls/app_data:/opt/devolutions/dvls/App_Data" "/srv/dvls/certs:/opt/devolutions/dvls/certs:ro" ];
  volumeArgs = lib.concatMapStringsSep " " (v: "-v ${v}") volumes;
in {
  sops.secrets."dvls/env" = {
    sopsFile = ../../../secrets/common.yaml;
    restartUnits = [ "docker-dvls-db.service" "docker-dvls.service" ];
  };

  systemd.services.dvls-net = {
    after = [ "docker.service" ]; requires = [ "docker.service" ];
    before = [ "docker-dvls-db.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    # The image makes a new self-signed certificate on every start, which clients would have to
    # trust again each time, so one is generated here once and mounted.
    script = ''
      ${docker} network inspect ${net} >/dev/null 2>&1 || ${docker} network create ${net}
      [ -f /srv/dvls/certs/server.pem ] || ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -keyout /srv/dvls/certs/server.key -out /srv/dvls/certs/server.pem -subj "/CN=${host}" -addext "subjectAltName=IP:${host}"
    '';
  };

  # First start against an empty database. A second init fails because the administrator exists,
  # and init mode keeps serving after it finishes, so it runs once and is stopped on its log line.
  systemd.services.dvls-init = {
    after = [ "docker-dvls-db.service" ]; requires = [ "docker-dvls-db.service" ];
    before = [ "docker-dvls.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "!/srv/dvls/app_data/.initialized";
    serviceConfig = { Type = "oneshot"; TimeoutStartSec = "15min"; };
    script = ''
      until ${docker} exec dvls-db pg_isready -U dvls -d dvls; do sleep 2; done
      ${docker} rm -f dvls-init 2>/dev/null || true
      ${docker} run -d --name dvls-init --network ${net} --env-file ${envFile} ${envArgs} -e DVLS_INIT=true ${volumeArgs} ${image}
      until ${docker} logs dvls-init 2>&1 | grep -q "Initialization completed successfully."; do
        [ "$(${docker} inspect -f '{{.State.Running}}' dvls-init)" = true ] || { ${docker} logs dvls-init; exit 1; }
        sleep 5
      done
      ${docker} rm -f dvls-init
      touch /srv/dvls/app_data/.initialized
    '';
  };

  virtualisation.oci-containers.containers = {
    dvls-db = {
      image = "postgres:17.11@sha256:ff87138949ad9a46f32ff23bd6852b52ce024a13dffe9b4087be98292cdd3b4f";
      # The role stays superuser: schema upgrades change type casts, and nothing else uses this server.
      environment = { POSTGRES_USER = "dvls"; POSTGRES_DB = "dvls"; };
      environmentFiles = [ envFile ];
      volumes = [ "/srv/dvls/db:/var/lib/postgresql/data" ];
      extraOptions = [ "--network=${net}" "--network-alias=db" ];
    };
    dvls = {
      inherit image environment volumes;
      dependsOn = [ "dvls-db" ];
      environmentFiles = [ envFile ];
      ports = [ "443:5000" ];
      extraOptions = [ "--network=${net}" ];
    };
  };

  systemd.services.docker-dvls-db.after = [ "dvls-net.service" ];
  systemd.services.docker-dvls.after = [ "dvls-init.service" ];

  systemd.tmpfiles.rules = [
    "d /srv/dvls 0755 root root -"
    "d /srv/dvls/app_data 0700 root root -"
    "d /srv/dvls/certs 0700 root root -"
    "d /srv/dvls/db 0700 999 999 -"   # postgres in the postgres image
  ];

  networking.firewall.allowedTCPPorts = [ 443 ];
}
