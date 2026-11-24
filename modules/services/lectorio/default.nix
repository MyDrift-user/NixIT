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
  compose = "${docker} compose -p lectorio -f ${src}/docker-compose.yml --env-file ${envFile}";
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
    restartTriggers = [ src ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "1h";   # first start builds the Rust API and the Angular app
      ExecStart = "${compose} up -d --build --remove-orphans";
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

  # Testing phase: every name behind the Pangolin login (owner, 2026-11-24). The stack's nginx splits
  # by Host (www -> 301 apex, app.* = the app). robots.txt is static and answers on every host.
  nixit.pangolin.resources = [
    { key = "lectorio"; name = "Lectorio"; fullDomain = "lectorio.space"; port = 8480; sso = true; healthPath = "/robots.txt"; }
    { key = "lectorio-www"; name = "Lectorio (www)"; fullDomain = "www.lectorio.space"; port = 8480; sso = true; healthPath = "/robots.txt"; }
    { key = "lectorio-app"; name = "Lectorio App"; fullDomain = "app.lectorio.space"; port = 8480; sso = true; healthPath = "/robots.txt"; }
  ];
}
