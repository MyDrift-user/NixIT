# FortiGate SSL-VPN client (openfortivpn).
#
# openfortivpn is open-source with no license and no client-side time limit.
# The "8h limit" people hit is the FortiGate's server-side `auth-timeout`
# (default 28800s), not the client. `Restart=always` re-authenticates across it
# (with the stored creds) so the tunnel is effectively non-stop — unlike free
# FortiClient, which can't auto-reconnect without an EMS license. Seamless
# reconnect needs username/password auth (MFA/SAML would interrupt it).
#
# Routing the tunnel to your users (headscale subnet router, etc.) is handled
# separately — this module only brings up and holds the VPN.
#
# Secret (sops secrets/common.yaml, key `fortivpn/config`) — openfortivpn config:
#     host = vpn.fathercorp.example
#     port = 443
#     username = <user>
#     password = <pass>
#     trusted-cert = <sha256>      # openfortivpn prints it on first connect
#     set-dns = 0
#     pppd-use-peerdns = 0
{ config, pkgs, ... }:
{
  sops.secrets."fortivpn/config".sopsFile = ../../../secrets/common.yaml;
  environment.systemPackages = [ pkgs.openfortivpn ];

  systemd.services.openfortivpn = {
    description = "FortiGate SSL VPN (openfortivpn)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.ppp ];
    serviceConfig = {
      ExecStart = "${pkgs.openfortivpn}/bin/openfortivpn -c ${config.sops.secrets."fortivpn/config".path}";
      Restart = "always";          # auto-reconnect across the FortiGate auth-timeout
      RestartSec = 10;
    };
  };
}
