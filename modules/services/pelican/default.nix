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
# No sops secret: the panel generates its APP_KEY into /srv/pelican/data on first run.
{ config, ... }:
let
  cfg = config.nixit;
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
        # Behind Pangolin (TLS terminated upstream) — tell the panel's bundled
        # Caddy it's behind a proxy so it serves HTTP and doesn't try Let's Encrypt.
        TRUSTED_PROXIES = "*";
      };
      volumes = [
        "/srv/pelican/data:/pelican-data"
        "/srv/pelican/logs:/var/www/html/storage/logs"
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
    "d /etc/pelican 0750 root root -"
    "d /var/lib/pelican 0750 root root -"
    "d /var/log/pelican 0750 root root -"
    "d /tmp/pelican 0750 root root -"
  ];

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
