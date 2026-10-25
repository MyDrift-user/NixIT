# WD Gruppe websites (~/Projects/wdc/web): one prerendered Angular site per company, each on
# its own port. nginx does what that repo's scripts/serve.ts does: clean URLs, the locale's own
# 404 page with a real 404, / -> /de, no-cache HTML and immutable assets, security headers.
#
# Content is not in the store: copy dist/<site>/browser to /srv/wd-web/<site>/, write the
# build's csp.txt minus upgrade-insecure-requests (the ports are plain HTTP) as
# /srv/wd-web/<site>/csp.nginx (add_header Content-Security-Policy "..." always;), reload nginx.
{ lib, ... }:
let
  sites = {
    william-diana-consulting = 8081;
    wd-consulting = 8082;
    wd-immobilien-finanz = 8083;
  };

  security = name: ''
    include /srv/wd-web/${name}/*.nginx;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header Permissions-Policy "accelerometer=(), autoplay=(), camera=(), display-capture=(), encrypted-media=(), fullscreen=(self), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), midi=(), payment=(), usb=()" always;
    add_header Cross-Origin-Opener-Policy same-origin always;
    add_header Cross-Origin-Resource-Policy same-origin always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
  '';

  # add_header in a location drops the server's, so every location carries the full set.
  locale = name: loc: {
    tryFiles = "$uri $uri/index.html =404";
    extraConfig = ''
      error_page 404 /${loc}/404/index.html;
      ${security name}
      add_header Cache-Control $wd_cache always;
    '';
  };

  vhost = name: port: {
    listen = [ { addr = "0.0.0.0"; inherit port; } { addr = "[::]"; inherit port; } ];
    root = "/srv/wd-web/${name}";
    extraConfig = ''
      absolute_redirect off;   # relative Location, right behind any proxy
      charset utf-8;
    '';
    locations = {
      "= /".return = "302 /de";
      "/" = locale name "de";
      "/it/" = locale name "it";
      "/en/" = locale name "en";
    };
  };
in {
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    # Hashed assets are immutable; HTML (also when reached as dir/index.html) revalidates.
    appendHttpConfig = ''
      map $sent_http_content_type $wd_cache {
        ~^text/html no-cache;
        default "public, max-age=31536000, immutable";
      }
    '';
    virtualHosts = lib.mapAttrs' (name: port: lib.nameValuePair name (vhost name port)) sites;
  };

  networking.firewall.allowedTCPPorts = lib.attrValues sites;

  systemd.tmpfiles.rules = [ "d /srv/wd-web 0755 root root -" ]
    ++ map (name: "d /srv/wd-web/${name} 0755 root root -") (lib.attrNames sites);
}
