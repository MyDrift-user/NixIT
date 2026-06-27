# moodleng — your app (github.com/mydrift-user/MoodleNG), converted from its
# compose.yaml. One combined image (nginx + Next.js frontend + Rust backend) +
# PostgreSQL + Collabora (online office editing). Public registry, no pull auth.
#
# Secrets (sops secrets/common.yaml):
#   moodleng/db-env   -> POSTGRES_PASSWORD=<pw>
#   moodleng/app-env  -> DATABASE_URL=postgres://moodleng:<pw>@moodleng-db:5432/moodleng
#                        JWT_SECRET=<openssl rand -hex 32>
#                        OPENAI_API_KEY=<key>        # AI features (optional)
#
# Non-secret config (MOODLE_URL, FRONTEND_URL) is inline below — EDIT before use.
{ config, ... }:
let
  net = "moodlengnet";
  docker = "${config.virtualisation.docker.package}/bin/docker";
in {
  sops.secrets."moodleng/db-env".sopsFile  = ../../../secrets/common.yaml;
  sops.secrets."moodleng/app-env".sopsFile = ../../../secrets/common.yaml;

  systemd.services.init-moodleng-net = {
    description = "create moodleng docker network";
    after = [ "docker.service" "docker.socket" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = "${docker} network inspect ${net} >/dev/null 2>&1 || ${docker} network create ${net}";
  };

  virtualisation.oci-containers.containers = {
    moodleng-db = {
      image = "postgres:17-alpine";
      volumes = [ "/srv/moodleng/db:/var/lib/postgresql/data" ];
      environment = { POSTGRES_DB = "moodleng"; POSTGRES_USER = "moodleng"; };
      environmentFiles = [ config.sops.secrets."moodleng/db-env".path ];
      extraOptions = [ "--network=${net}" ];
    };

    collabora = {
      image = "collabora/code:latest";          # pin a tag in production
      environment = {
        aliasgroup1 = "http://moodleng:3001";
        extra_params = "--o:ssl.enable=false --o:ssl.termination=false --o:welcome.enable=false --o:user_interface.mode=notebookbar --o:net.service_root=/collabora --o:storage.wopi.host[0]=.*";
        username = "admin";
        password = "admin";                     # admin console only; not user-facing
      };
      extraOptions = [
        "--network=${net}"
        "--cap-add=MKNOD" "--cap-add=SYS_ADMIN"
        "--security-opt=seccomp=unconfined"
      ];
    };

    moodleng = {
      image = "ghcr.io/mydrift-user/moodleng:latest";   # public; verify name + pin a tag
      dependsOn = [ "moodleng-db" "collabora" ];
      ports = [ "127.0.0.1:3033:80" ];          # front with a reverse proxy (ingress TBD)
      environment = {
        # ── EDIT these two ──────────────────────────────────────────────
        MOODLE_URL = "https://moodle.example.com";      # your Moodle instance (required)
        FRONTEND_URL = "https://learn.lua.li";          # this app's public URL
        # ── plumbing ────────────────────────────────────────────────────
        MOODLE_ALLOW_CUSTOM = "false";
        JWT_EXPIRY_HOURS = "24";
        BACKEND_PORT = "3001";
        MOODLE_LOG_DIR = "/app/logs/moodle_responses";
        WORKSPACE_STORAGE_DIR = "/app/workspace_data";
        COLLABORA_URL = "http://collabora:9980";
        WOPI_URL = "http://moodleng:3001";
        MAX_UPLOAD_SIZE_MB = "100";
      };
      environmentFiles = [ config.sops.secrets."moodleng/app-env".path ];  # DATABASE_URL, JWT_SECRET, OPENAI_API_KEY
      volumes = [
        "/srv/moodleng/logs:/app/logs"
        "/srv/moodleng/workspace:/app/workspace_data"
      ];
      extraOptions = [ "--network=${net}" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/moodleng 0750 root root -"
    "d /srv/moodleng/db 0700 70 70 -"   # postgres (alpine uid 70) owns its data — don't reset to root
    "d /srv/moodleng/logs 0750 root root -"
    "d /srv/moodleng/workspace 0750 root root -"
  ];
}
