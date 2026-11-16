# Kodama: the niwa compose stack (git.lua.li/kodama/niwa, main) in /opt/kodama/niwa, brought up and
# upgraded with compose/scripts/up.sh as niwa/docs/deploy.md describes. Images are the released
# git.lua.li/kodama/<image>:<KODAMA_TAG>; prune stays off so a stopped module keeps its image.
#
# edge listens on loopback (EDGE_BIND=127.0.0.1); newt reaches it on localhost, nothing is open on
# the LAN. Secrets (Entra client secret) live only in /opt/kodama/niwa on the VM. Backups
# (KODAMA_BACKUP_DIR) go to the NAS mount the host entry declares.
{ lib, pkgs, inputs, ... }:
let
  # niwa's compose files override a service an included file defines; Compose 2.40 (nixos-25.11)
  # refuses that ("conflicts with imported resource"), 5.x accepts it. Root's CLI plugin wins over the
  # system one, so root's `docker compose` is this.
  compose = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.docker-compose;
in {
  virtualisation.docker.autoPrune.enable = lib.mkForce false;
  # The fleet's /27 networks hold 30 containers; Kodama's one network holds more (migrations
  # included). No 192.168.0.0/16 pool here: on a WDC host it could take 192.168.17.0/24, the client LAN.
  virtualisation.docker.daemon.settings.default-address-pools = lib.mkForce [ { base = "172.17.0.0/16"; size = 24; } ];
  systemd.tmpfiles.rules = [
    "d /opt/kodama 0750 root root -"
    "d /root/.docker/cli-plugins 0700 root root -"
    "L+ /root/.docker/cli-plugins/docker-compose - - - - ${compose}/libexec/docker/cli-plugins/docker-compose"
  ];

  environment.systemPackages = with pkgs; [ git curl openssl python3 bash ];
}
