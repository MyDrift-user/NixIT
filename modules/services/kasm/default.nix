# Kasm — no native module; install via sudo kasm-install
{ config, lib, pkgs, ... }:
let
  adminPw = config.sops.secrets."kasm/admin-password".path;
  kasm-install = pkgs.writeShellScriptBin "kasm-install" ''
    set -euo pipefail
    [ "$(id -u)" -eq 0 ] || { echo "run as root: sudo kasm-install [release-url]"; exit 1; }
    url="$1"; [ -n "$url" ] || url="${config.nixit.kasm.releaseUrl}"
    [ -n "$url" ] || { echo "usage: sudo kasm-install <release-tarball-url>  (https://www.kasmweb.com/downloads)"; exit 1; }
    cd /opt/kasm
    if [ ! -d kasm_release ]; then
      ${pkgs.curl}/bin/curl -fSL -o kasm_release.tar.gz "$url"
      ${pkgs.gnutar}/bin/tar -xf kasm_release.tar.gz
    fi
    bash kasm_release/install.sh --accept-eula --swap-size 4096 \
      --admin-password "$(cat ${adminPw})" \
      --user-password  "$(cat ${adminPw})"
    kasm-proxy-healthcheck
    echo "Kasm installed. Admin UI: https://office.lua.li (or https://<this-host>)."
  '';
  # Kasm ships every container with a healthcheck except its own nginx proxy,
  # and that omission is what takes office.lua.li down. nginx resolves its
  # upstreams once at start and caches them, so an app container that restarts
  # onto a different address leaves the proxy answering 502 for good; autoheal
  # repairs every other container but never sees this one. Giving the proxy a
  # healthcheck that exercises its own upstreams lets autoheal restart it,
  # which is how it picks the new addresses up. Measured recovery: 51 seconds.
  #
  # Run by kasm-install as well, because an upgrade rewrites the compose file.
  kasm-proxy-healthcheck = pkgs.writeShellScriptBin "kasm-proxy-healthcheck" ''
    set -euo pipefail
    F=/opt/kasm/current/docker/docker-compose.yaml
    [ -f "$F" ] || { echo "no compose file at $F; is Kasm installed?"; exit 1; }
    if ${pkgs.gnugrep}/bin/grep -q "api/__healthcheck || exit 1" "$F"; then
      echo "kasm_proxy healthcheck already present"; exit 0
    fi
    cp "$F" "$F.pre-healthcheck"
    ${pkgs.gawk}/bin/awk '
    /^  proxy:$/ { inproxy = 1 }
    inproxy && /^    ports:$/ && !patched {
      print "    healthcheck:"
      print "      test: [\"CMD-SHELL\", \"curl -fsk -o /dev/null --max-time 5 https://localhost/api/__healthcheck || exit 1\"]"
      print "      interval: 30s"
      print "      timeout: 10s"
      print "      retries: 3"
      print "      start_period: 60s"
      patched = 1
    }
    { print }
    ' "$F" > "$F.new"
    mv "$F.new" "$F"
    echo "kasm_proxy healthcheck added; run /opt/kasm/bin/stop && /opt/kasm/bin/start to apply"
  '';


in {
  options.nixit.kasm.releaseUrl = lib.mkOption {
    type = lib.types.str;
    default = "";
    example = "https://kasm-static-content.s3.amazonaws.com/kasm_release_1.17.0.7f020d.tar.gz";
    description = "Default Kasm release tarball URL (the file name carries a build hash; copy it from kasmweb.com/downloads).";
  };

  config = {
    # Kasm runs from its vendor compose file, not from NixOS units. The fleet's daily
    # `docker system prune --all` (modules/server/docker) deletes any Kasm container that is stopped
    # at that moment, its image, the then unused kasm_sidecar_network, and every workspace image no
    # session uses; restart: always cannot bring a deleted container or network back, and
    # office.lua.li stayed at 503 until it was rebuilt by hand (2026-08-28, again 2026-11-24).
    virtualisation.docker.autoPrune.enable = lib.mkForce false;

    # Self-heal: on boot and every 15 minutes, recreate the sidecar network and any missing Kasm
    # container with Kasm's own bin/start. Only runs bin/start when something is missing, because it
    # pulls every image (Docker Hub rate limits).
    systemd.services.kasm-ensure = {
      description = "Recreate missing Kasm containers and network";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      path = [ config.virtualisation.docker.package pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.shadow ];
      serviceConfig.Type = "oneshot";
      script = ''
        F=/opt/kasm/current/docker/docker-compose.yaml
        [ -f "$F" ] || { echo "Kasm not installed"; exit 0; }
        docker network inspect kasm_sidecar_network >/dev/null 2>&1 \
          || docker network create --driver bridge --attachable kasm_sidecar_network
        running=$(docker ps --format '{{.Names}}')
        missing=""
        for c in $(grep -oE 'container_name: kasm_[a-z_]+' "$F" | cut -d' ' -f2); do
          echo "$running" | grep -qx "$c" || missing="$missing $c"
        done
        if [ -n "$missing" ]; then
          echo "kasm: not running:$missing; starting"
          /opt/kasm/current/bin/start
          # newt reports a target healthy again only after a reconnect, so wait for the proxy and
          # restart it; otherwise office.lua.li stays 503 although Kasm is back.
          for _ in $(seq 1 36); do
            ${pkgs.curl}/bin/curl -fsk -o /dev/null --max-time 5 https://127.0.0.1/api/__healthcheck && break
            sleep 5
          done
          systemctl restart docker-newt.service || true
        fi
      '';
    };
    systemd.timers.kasm-ensure = {
      wantedBy = [ "timers.target" ];
      timerConfig = { OnBootSec = "2min"; OnUnitActiveSec = "15min"; };
    };

    networking.firewall.allowedTCPPorts = [ 443 8443 ];
    systemd.tmpfiles.rules = [ "d /opt/kasm 0750 root root -" ];
    sops.secrets."kasm/admin-password".sopsFile = ../../../secrets/common.yaml;

    environment.systemPackages = [ kasm-install kasm-proxy-healthcheck pkgs.curl pkgs.gnutar pkgs.lsof pkgs.procps pkgs.which pkgs.iproute2 pkgs.gawk pkgs.gnused ];

    users.motd = ''
      Kasm host — prepared, not yet installed.
        1) sudo kasm-install <release-url from https://www.kasmweb.com/downloads>
           admin + user passwords are taken from sops (kasm/admin-password)
        2) Admin UI (proxied at https://office.lua.li):
           - OIDC: Issuer https://mdl.auth.li/realms/main, client "kasm" (id + secret)
                   map a Keycloak group/role -> a Kasm group for auto-provisioning
           - Groups > Settings: default Workspace (login lands in it) + Volume
             Mappings for network shares (//fileserver/share -> /home/kasm-user/share)
    '';
  };
}
