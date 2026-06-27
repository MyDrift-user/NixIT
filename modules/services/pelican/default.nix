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

  # Ensure the generic-oidc-providers plugin is present + its composer dep is
  # installed (vendor is ephemeral, so re-run each boot), then reload the panel.
  systemd.services.pelican-oidc-plugin = {
    description = "Pelican: generic-oidc-providers plugin + composer deps";
    after = [ "docker-pelican-panel.service" ];
    requires = [ "docker-pelican-panel.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.curl pkgs.gnutar ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      set -eu
      if [ ! -f /srv/pelican/plugins/generic-oidc-providers/plugin.json ]; then
        tmp=$(mktemp -d)
        curl -fsSL https://github.com/pelican-dev/plugins/archive/refs/heads/main.tar.gz | tar -xz -C "$tmp"
        cp -r "$tmp"/plugins-*/generic-oidc-providers /srv/pelican/plugins/
        rm -rf "$tmp"
      fi
      chown -R 82:82 /srv/pelican/plugins
      for i in $(seq 1 40); do ${docker} exec pelican-panel php artisan --version >/dev/null 2>&1 && break; sleep 3; done
      ${docker} exec pelican-panel php artisan p:plugin:install generic-oidc-providers --silent || true
      ${docker} exec pelican-panel php artisan p:plugin:composer || true
      ${docker} restart pelican-panel >/dev/null 2>&1 || true
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
