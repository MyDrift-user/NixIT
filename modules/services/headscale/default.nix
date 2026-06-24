# Headscale — self-hosted Tailscale control server. Native services.headscale,
# OIDC against Keycloak wired declaratively (client_secret_path from sops).
# Control URL (server_url): vpn.lua.li (via Pangolin -> newt -> :8080).
#
# Secret (sops secrets/common.yaml): headscale/oidc-client-secret
#   == HEADSCALE_CLIENT_SECRET in keycloak/env.
{ config, ... }:
let
  cfg = config.nixit;
in {
  sops.secrets."headscale/oidc-client-secret".sopsFile = ../../../secrets/common.yaml;

  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 8080;
    settings = {
      server_url = "https://vpn.${cfg.serviceDomain}";
      dns.base_domain = "ts.${cfg.internalDomain}";   # MagicDNS tailnet domain (distinct from server_url)
      oidc = {
        issuer = "${cfg.authUrl}/realms/${cfg.realm}";
        client_id = "headscale";
        client_secret_path = config.sops.secrets."headscale/oidc-client-secret".path;
        scope = [ "openid" "profile" "email" ];
      };
    };
  };

  # Manage with `headscale` CLI on the host (create users, pre-auth keys, list
  # nodes). Clients: `tailscale up --login-server=https://vpn.lua.li`.
}
