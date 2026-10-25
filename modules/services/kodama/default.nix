# Kodama test instance: the niwa compose stack (git.lua.li/kodama/niwa) in /opt/kodama/niwa,
# run by hand with docker compose as niwa/docs/deploy.md describes. Its images are copied from
# wsmdp-001 (tag dev-local, most are in no registry), so docker must never prune them.
#
# edge listens on loopback (EDGE_BIND=127.0.0.1); newt reaches it on localhost, nothing is open on
# the LAN. Secrets (Entra client secret, SMTP password) live only in /opt/kodama/niwa on the VM.
{ lib, pkgs, ... }: {
  virtualisation.docker.autoPrune.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [ git curl openssl python3 bash ];

  systemd.tmpfiles.rules = [ "d /opt/kodama 0750 root root -" ];
}
