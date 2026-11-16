# Kodama: the niwa compose stack (git.lua.li/kodama/niwa, main) in /opt/kodama/niwa, brought up and
# upgraded with compose/scripts/up.sh as niwa/docs/deploy.md describes. Images are the released
# git.lua.li/kodama/<image>:<KODAMA_TAG>; prune stays off so a stopped module keeps its image.
#
# edge listens on loopback (EDGE_BIND=127.0.0.1); newt reaches it on localhost, nothing is open on
# the LAN. Secrets (Entra client secret) live only in /opt/kodama/niwa on the VM. Backups
# (KODAMA_BACKUP_DIR) go to the NAS mount the host entry declares.
{ lib, pkgs, ... }: {
  virtualisation.docker.autoPrune.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [ git curl openssl python3 bash ];

  systemd.tmpfiles.rules = [ "d /opt/kodama 0750 root root -" ];
}
