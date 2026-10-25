# faustoandfurio.ch: WordPress + MariaDB, the stack from the faustoandfurio-wp repo
# (docker-compose.yml) moved onto NixOS as is. docker/ is that repo's image context,
# plus the bare-domain -> www redirect in security.conf.
#
# Data: /srv/faustoandfurio/wp (WordPress files, uploads, plugins) and
# /srv/faustoandfurio/db (MariaDB datadir). Secret: sops faustoandfurio/env with
# MARIADB_PASSWORD= and WORDPRESS_DB_PASSWORD= (same value).
{ config, lib, ... }:
let
  # true: WordPress is stopped and nginx answers on its port with maintenance/index.html (503).
  maintenance = false;

  net = "faustoandfurio-net";
  image = "faustoandfurio-wordpress:local";
  docker = "${config.virtualisation.docker.package}/bin/docker";
  envFile = config.sops.secrets."faustoandfurio/env".path;
  build = "${docker} build --pull -t ${image} ${./docker}";
in lib.mkMerge [ {
  sops.secrets."faustoandfurio/env" = {
    sopsFile = ../../../secrets/common.yaml;
    restartUnits = [ "docker-faustoandfurio-db.service" "docker-faustoandfurio-wordpress.service" ];
  };

  systemd.services.init-faustoandfurio = {
    after = [ "docker.service" ]; requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    before = [ "docker-faustoandfurio-db.service" "docker-faustoandfurio-wordpress.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    # The store path changes with the context, so a changed Dockerfile reruns this unit.
    script = ''
      ${docker} network inspect ${net} >/dev/null 2>&1 || ${docker} network create ${net}
      ${build}
    '';
  };

  virtualisation.oci-containers.containers = {
    faustoandfurio-db = {
      image = "mariadb:11.4";
      environment = { MARIADB_DATABASE = "wordpress"; MARIADB_USER = "wordpress"; MARIADB_RANDOM_ROOT_PASSWORD = "1"; };
      environmentFiles = [ envFile ];
      volumes = [ "/srv/faustoandfurio/db:/var/lib/mysql" ];
      extraOptions = [ "--network=${net}" "--network-alias=db" ];
    };
  };

  systemd.services.docker-faustoandfurio-db.after = [ "init-faustoandfurio.service" ];

  systemd.tmpfiles.rules = [
    "d /srv/faustoandfurio 0755 root root -"
    "d /srv/faustoandfurio/wp 0755 33 33 -"     # www-data in the wordpress image
    "d /srv/faustoandfurio/db 0700 999 999 -"   # mysql in the mariadb image
  ];

  # Public site: no Pangolin login. The bare domain is its own resource and Apache
  # answers it with a 301 to www. blank.gif is static, so the check does not depend
  # on the Host header WordPress would canonicalise.
  nixit.pangolin.resources = [
    { key = "faustoandfurio-www"; name = "Fausto & Furio"; fullDomain = "www.faustoandfurio.ch"; port = 8088; sso = false; healthPath = "/wp-includes/images/blank.gif"; }
    { key = "faustoandfurio-root"; name = "Fausto & Furio (root)"; fullDomain = "faustoandfurio.ch"; port = 8088; sso = false; healthPath = "/wp-includes/images/blank.gif"; }
  ];
}
(lib.mkIf (!maintenance) {
  virtualisation.oci-containers.containers = {
    faustoandfurio-wordpress = {
      inherit image;
      dependsOn = [ "faustoandfurio-db" ];
      environment = {
        WORDPRESS_DB_HOST = "db";
        WORDPRESS_DB_NAME = "wordpress";
        WORDPRESS_DB_USER = "wordpress";
        WORDPRESS_CONFIG_EXTRA = ''
          define('DISALLOW_FILE_EDIT', true);
          define('WP_AUTO_UPDATE_CORE', true);
          define('WP_POST_REVISIONS', 20);
          define('WP_ENVIRONMENT_TYPE', 'production');
          if (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? ''') === 'https') { $_SERVER['HTTPS'] = 'on'; }
        '';
      };
      environmentFiles = [ envFile ];
      # newt dials localhost as ::1 first, so publish on every address, not 127.0.0.1.
      ports = [ "8088:80" ];
      volumes = [ "/srv/faustoandfurio/wp:/var/www/html" ];
      extraOptions = [ "--network=${net}" ];
    };
  };

  systemd.services.docker-faustoandfurio-wordpress = {
    after = [ "init-faustoandfurio.service" ];
    restartTriggers = [ ./docker ];   # a rebuilt image only runs once the container restarts
  };
  # The context only changes with this repo, so PHP fixes in the base image would never arrive.
  # Rebuild hourly against the newest wordpress:php8.3-apache (cached, so a no-op unless the base
  # moved); restart only when the image changed.
  systemd.services.update-faustoandfurio = {
    after = [ "init-faustoandfurio.service" ]; requires = [ "docker.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      old=$(${docker} image inspect -f '{{.Id}}' ${image} 2>/dev/null || true)
      ${build}
      if [ "$(${docker} image inspect -f '{{.Id}}' ${image})" != "$old" ]; then
        systemctl restart docker-faustoandfurio-wordpress.service
        ${docker} image prune -f
      fi
    '';
  };
  systemd.timers.update-faustoandfurio = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "hourly"; RandomizedDelaySec = "10m"; Persistent = true; };
  };
})
(lib.mkIf maintenance {
  # The health path stays 200 so Pangolin keeps routing here; the bare domain still goes to www.
  services.nginx = {
    enable = true;
    virtualHosts.faustoandfurio-maintenance = {
      listen = [ { addr = "0.0.0.0"; port = 8088; } { addr = "[::]"; port = 8088; } ];
      root = ./maintenance;
      extraConfig = ''
        if ($host = faustoandfurio.ch) { return 301 https://www.faustoandfurio.ch$request_uri; }
        error_page 503 /index.html;
      '';
      locations."= /wp-includes/images/blank.gif".return = "200";
      locations."= /index.html".extraConfig = "internal; add_header Retry-After 3600 always;";
      locations."/".return = "503";
    };
  };
}) ]
