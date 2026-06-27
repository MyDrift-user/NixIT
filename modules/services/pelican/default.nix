# Pelican — open-source game server panel (Minecraft, Terraria, and ~anything
# that runs in Docker). Two containers:
#   - pelican-panel : the web UI / control plane (behind Pangolin at game.lua.li)
#   - pelican-wings : the daemon that runs each game server as a Docker container
#                     on THIS host (needs the Docker socket + a game-port range)
#
# Honest scoping (like Kasm): Wings is configured at RUNTIME — you create a Node
# in the panel UI and paste its config to /etc/pelican/config.yml — so it can't be
# fully declarative. This module deploys both containers, stages the dirs, and
# opens the ports; finish setup via README.md. Pelican has its own auth (no OIDC).
#
# Keycloak SSO: via the first-party `generic-oidc-providers` plugin (Boy132),
# fetched into the persisted plugins volume + its composer dep restored on each
# boot (vendor is ephemeral). Provider is configured in the DB table
# `generic_oidc_providers`; the Keycloak `pelican` client is in the realm import.
#
# No sops secret: the panel generates its APP_KEY into /srv/pelican/data on first run.
{ config, pkgs, ... }:
let
  cfg = config.nixit;
  docker = "${config.virtualisation.docker.package}/bin/docker";
in {
  virtualisation.oci-containers.containers = {
    pelican-panel = {
      image = "ghcr.io/pelican-dev/panel:latest";    # pin a tag in production
      ports = [ "127.0.0.1:8085:80" ];               # HTTP -> Pangolin/newt (TLS at Pangolin)
      environment = {
        APP_URL       = "https://game.${cfg.serviceDomain}";
        APP_ENV       = "production";
        APP_DEBUG     = "false";
        APP_TIMEZONE  = "Europe/Zurich";
        MAIL_DRIVER   = "log";
        XDG_DATA_HOME = "/pelican-data";
        # Behind Pangolin (TLS terminated upstream) — the panel entrypoint checks
        # BEHIND_PROXY to skip its own Let's Encrypt and serve plain HTTP.
        BEHIND_PROXY = "true";
        TRUSTED_PROXIES = "0.0.0.0/0";   # Caddy needs a CIDR, not "*" (only Pangolin reaches the localhost-bound panel)
      };
      volumes = [
        "/srv/pelican/data:/pelican-data"
        "/srv/pelican/logs:/var/www/html/storage/logs"
        "/srv/pelican/plugins:/var/www/html/plugins"   # persist the OIDC plugin code
      ];
    };

    pelican-wings = {
      image = "ghcr.io/pelican-dev/wings:latest";    # pin a tag in production
      ports = [ "8080:8080" "2022:2022" ];           # daemon API/console + SFTP
      environment = {
        TZ            = "Europe/Zurich";
        WINGS_UID     = "988";
        WINGS_GID     = "988";
        WINGS_USERNAME = "pelican";
      };
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
        "/var/lib/docker/containers:/var/lib/docker/containers"
        "/etc/pelican:/etc/pelican"
        "/var/lib/pelican:/var/lib/pelican"
        "/var/log/pelican:/var/log/pelican"
        "/tmp/pelican:/tmp/pelican"
        "/etc/ssl/certs:/etc/ssl/certs:ro"
      ];
      extraOptions = [ "--tty" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/pelican 0755 root root -"
    "d /srv/pelican/data 0777 root root -"
    "d /srv/pelican/logs 0777 root root -"
    "d /srv/pelican/plugins 0755 82 82 -"   # www-data (uid 82) owns the plugins dir
    "d /etc/pelican 0750 root root -"
    "d /var/lib/pelican 0750 root root -"
    "d /var/log/pelican 0750 root root -"
    "d /tmp/pelican 0750 root root -"
  ];

  # Keep the generic-oidc-providers plugin present + its composer dep installed.
  # The plugin CODE lives in the persisted /srv/pelican/plugins volume, but its
  # composer dep (kovah/laravel-socialite-oidc) is installed into the panel's
  # /var/www/html/vendor, which is INSIDE the container layer — wiped whenever the
  # container is recreated (deploy / image update). So we re-run on every panel
  # (re)start (partOf the panel service) to restore it.
  #
  # Decoupled + non-fatal by design: `wants` not `requires`, no `set -e`, every
  # step `|| true`, `exit 0`. It uses `docker restart` (keeps the writable layer,
  # so the freshly-installed vendor survives the reload) — NOT `systemctl restart`
  # (which would recreate the container and wipe vendor again, looping). This must
  # never be able to fail/slow a deploy into a magic-rollback.
  systemd.services.pelican-oidc-plugin = {
    description = "Pelican: install generic-oidc-providers plugin + restore composer dep";
    after = [ "docker-pelican-panel.service" ];
    wants = [ "docker-pelican-panel.service" ];
    partOf = [ "docker-pelican-panel.service" ];
    wantedBy = [ "docker-pelican-panel.service" "multi-user.target" ];
    path = [ pkgs.curl pkgs.gnutar pkgs.coreutils ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; TimeoutStartSec = 600; };
    script = ''
      set -u
      PDIR=/srv/pelican/plugins/generic-oidc-providers
      # 1. Fetch the plugin into the persisted volume if missing. Download to a
      #    file (avoids the SIGPIPE that killed `curl | tar`) and extract ONLY the
      #    one subdir (the full plugins repo is large).
      if [ ! -f "$PDIR/plugin.json" ]; then
        tmp=$(mktemp -d)
        if curl -fsSL -o "$tmp/p.tgz" https://github.com/pelican-dev/plugins/archive/refs/heads/main.tar.gz; then
          tar -xzf "$tmp/p.tgz" -C "$tmp" --strip-components=1 plugins-main/generic-oidc-providers || true
          mkdir -p /srv/pelican/plugins
          cp -r "$tmp/generic-oidc-providers" /srv/pelican/plugins/ || true
        fi
        rm -rf "$tmp"
      fi
      chown -R 82:82 /srv/pelican/plugins 2>/dev/null || true
      # 2. Wait (bounded) for the panel's artisan to answer.
      for i in $(seq 1 30); do ${docker} exec pelican-panel php artisan --version >/dev/null 2>&1 && break; sleep 2; done
      # 3. (Re)install the plugin (idempotent) and restore its composer dep. Only
      #    restart the panel if the socialite OIDC class wasn't already loadable
      #    (i.e. vendor was wiped) — `docker restart` keeps the just-built vendor.
      need_restart=0
      ${docker} exec pelican-panel php -r 'exit(class_exists("SocialiteProviders\\OIDC\\Provider")?0:1);' >/dev/null 2>&1 || need_restart=1
      ${docker} exec pelican-panel php artisan p:plugin:install generic-oidc-providers --no-interaction >/dev/null 2>&1 || true
      ${docker} exec pelican-panel php artisan p:plugin:composer >/dev/null 2>&1 || true
      [ "$need_restart" = "1" ] && ${docker} restart pelican-panel >/dev/null 2>&1 || true
      exit 0
    '';
  };

  # Wings API (8080) + SFTP (2022) are reached directly; game servers Wings spins
  # up publish into these ranges (Minecraft ~25565, Terraria ~7777). Widen/narrow
  # as you add servers. TCP+UDP (some games use UDP).
  networking.firewall.allowedTCPPorts = [ 8080 2022 ];
  networking.firewall.allowedTCPPortRanges = [
    { from = 25500; to = 25600; }   # Minecraft servers
    { from = 7770;  to = 7780;  }   # Terraria servers
  ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 25500; to = 25600; }
    { from = 7770;  to = 7780;  }
  ];
}
