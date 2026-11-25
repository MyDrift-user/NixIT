# Lectorio (lectorio.space): the repo's own docker compose stack (db, garage, api, web, livekit, shot),
# source pinned as the private flake input `lectorio`. Update: `nix flake update lectorio`, deploy.
#
# Secret: sops lectorio/env, the stack's .env (URLs, garage/S3/LiveKit secrets, mail).
# Data: docker volumes lectorio_db, lectorio_garage-meta, lectorio_garage-data.
# Backup: nightly pg_dump + garage volumes to the MDL NAS (/volume1/MDL/lectorio), 14 dumps kept.
{ config, pkgs, inputs, ... }:
let
  src = inputs.lectorio;
  docker = "${config.virtualisation.docker.package}/bin/docker";
  envFile = config.sops.secrets."lectorio/env".path;
  # Built from a copy: every file in the store is dated 1970, so cargo's kept target folder takes changed
  # code as unchanged and the image gets the old binary. The copy has fresh dates.
  state = "/var/lib/lectorio";
  build = "${state}/src";
  compose = "${docker} compose -p lectorio -f ${build}/docker-compose.yml --env-file ${envFile}";

  # A new version (reload): the images are built under another name while the old stack serves, then the
  # changed containers are recreated. A failed build, a live session or a failed dump ends it before anything
  # running is touched; after fixing the cause: systemctl reload lectorio.
  update = pkgs.writeShellScript "lectorio-update" ''
    set -euo pipefail
    export PATH=${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.diffutils pkgs.util-linux config.virtualisation.docker.package ]}:$PATH
    next=${state}/src.next
    idle() {
      live=$(docker exec lectorio-db-1 psql -U lectorio -d lectorio -Atc 'select count(*) from sessions where ended_at is null')
      [ "$live" = 0 ] || { echo "a session is running live ($live), nothing changed"; exit 1; }
    }
    running=; docker container inspect lectorio-db-1 > /dev/null 2>&1 && running=1
    [ -z "$running" ] || idle
    rm -rf $next
    cp -rT ${src} $next
    docker compose -p lectorio-next -f $next/docker-compose.yml --env-file ${envFile} build
    if [ -n "$running" ]; then
      mountpoint -q ${backupDir} || { echo "${backupDir} is not mounted, nothing changed"; exit 1; }
      mkdir -p ${backupDir}/predeploy
      dump=${backupDir}/predeploy/update-$(date +%F-%H%M%S).dump
      (umask 077; docker exec lectorio-db-1 pg_dump -U lectorio -Fc lectorio > $dump.tmp)
      mv $dump.tmp $dump
      idle
    fi
    for s in api shot web; do docker tag lectorio-next-$s:latest lectorio-$s:latest; done
    cmp -s $next/garage.toml ${build}/garage.toml && garage= || garage=1
    rm -rf ${build}
    mv $next ${build}
    echo ${src} > ${state}/version
    web=$(docker container inspect -f '{{.Id}}' lectorio-web-1 2> /dev/null || true)
    # First on its own: it ignores the stop signal, and the site would wait ten seconds for it.
    [ -z "$running" ] || ${compose} up -d --no-build --no-deps -t 1 shot
    ${compose} up -d --no-build --remove-orphans
    [ -z "$garage" ] || ${compose} up -d --no-build --no-deps --force-recreate garage
    # nginx looks the API's address up once, at its start.
    [ "$web" != "$(docker container inspect -f '{{.Id}}' lectorio-web-1)" ] || docker exec lectorio-web-1 nginx -s reload
  '';
  # A start (boot) brings up the version that last ran; only the first one builds.
  start = pkgs.writeShellScript "lectorio-start" ''
    [ -e ${state}/version ] || exec ${update}
    exec ${compose} up -d --no-build --remove-orphans
  '';
  backupDir = "/mnt/nas-lectorio";
in {
  sops.secrets."lectorio/env" = {
    sopsFile = ../../../secrets/common.yaml;
    restartUnits = [ "lectorio.service" ];
  };

  systemd.services.lectorio = {
    after = [ "docker.service" "network-online.target" ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    reloadIfChanged = true;   # never a stop: an update is the reload
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "1h";   # the build of the Rust API and the Angular app
      StateDirectory = "lectorio";
      ExecStart = start;
      ExecReload = update;
      ExecStop = "${compose} down";
    };
  };

  # LiveKit media from outside: the old Pangolin VPS 85.215.153.154 (VPSMDL-PANG-OLD) forwards 7881/tcp and
  # 7882/udp through this tunnel (DNAT + masquerade there, /etc/nftables.conf), so LIVEKIT_NODE_IP is its address.
  sops.secrets."lectorio/wg-key" = { sopsFile = ../../../secrets/common.yaml; };
  networking.wireguard.interfaces.wg-livekit = {
    ips = [ "10.99.33.2/30" ];
    privateKeyFile = config.sops.secrets."lectorio/wg-key".path;
    peers = [{
      publicKey = "IkZXvdPeAmoFuQGGwpKUQgYdPtupMNQ/doVmjlibQWA=";
      endpoint = "85.215.153.154:51820";
      allowedIPs = [ "10.99.33.1/32" ];
      persistentKeepalive = 25;
    }];
  };
  networking.firewall.interfaces.wg-livekit = { allowedTCPPorts = [ 7881 ]; allowedUDPPorts = [ 7882 ]; };

  # The images are built here; the fleet-wide prune would drop them while the stack is down.
  virtualisation.docker.autoPrune.enable = pkgs.lib.mkForce false;

  systemd.services.lectorio-backup = {
    after = [ "lectorio.service" ];
    path = [ pkgs.gzip pkgs.rsync pkgs.coreutils pkgs.findutils ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      mkdir -p ${backupDir}/db ${backupDir}/garage
      ${docker} exec lectorio-db-1 pg_dump -U lectorio -Fc lectorio > ${backupDir}/db/lectorio-$(date +%F).dump.tmp
      mv ${backupDir}/db/lectorio-$(date +%F).dump.tmp ${backupDir}/db/lectorio-$(date +%F).dump
      find ${backupDir}/db -name 'lectorio-*.dump' -mtime +14 -delete
      for v in garage-meta garage-data; do
        rsync -a --delete /var/lib/docker/volumes/lectorio_$v/_data/ ${backupDir}/garage/$v/
      done
    '';
  };
  systemd.timers.lectorio-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "*-*-* 03:30"; Persistent = true; };
  };

  # All names are public, the app has its own sign-in (owner, 2026-11-25). The stack's nginx splits
  # by Host (www -> 301 apex, app.* = the app). robots.txt is static and answers on every host.
  nixit.pangolin.resources = [
    { key = "lectorio"; name = "Lectorio"; fullDomain = "lectorio.space"; port = 8480; sso = false; healthPath = "/robots.txt"; }
    { key = "lectorio-www"; name = "Lectorio (www)"; fullDomain = "www.lectorio.space"; port = 8480; sso = false; healthPath = "/robots.txt"; }
    { key = "lectorio-app"; name = "Lectorio App"; fullDomain = "app.lectorio.space"; port = 8480; sso = false; healthPath = "/robots.txt"; }
  ];
}
