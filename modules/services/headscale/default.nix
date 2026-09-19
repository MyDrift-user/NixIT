# Headscale — self-hosted Tailscale control server. Native services.headscale,
# OIDC against Keycloak wired declaratively (client_secret_path from sops).
#
# The public control URL is reached through Pangolin -> newt -> :8080. An HTTP
# reverse proxy is enough: clients speak to the control plane over HTTPS only
# (/ts2021 is an HTTP Upgrade), the data plane is WireGuard between the nodes.
# The embedded DERP therefore stays off and nodes use Tailscale's public DERP
# map; a self-hosted relay would need UDP 3478 + a raw TCP path.
#
# Per-host knobs (nixit.headscale.*): public host, MagicDNS base domain, the
# Keycloak client, the sops key of its secret, and an optional subnet router
# (a tailscale client on this host that advertises LAN routes into the tailnet).
#
# Secret (sops secrets/common.yaml): <oidcSecretKey>, default headscale/oidc-client-secret
#   == HEADSCALE_CLIENT_SECRET in keycloak/env.
{ config, lib, pkgs, ... }:
let
  cfg = config.nixit;
  hs = cfg.headscale;
  serverUrl = "https://${hs.publicHost}";
  routes = lib.concatStringsSep "," hs.subnetRouter.routes;
in {
  options.nixit.headscale = {
    publicHost = lib.mkOption {
      type = lib.types.str;
      default = "vpn.${cfg.serviceDomain}";
      description = "Public hostname of the control server (server_url), published through Pangolin.";
    };
    baseDomain = lib.mkOption {
      type = lib.types.str;
      default = "ts.${cfg.internalDomain}";
      description = "MagicDNS base domain of the tailnet. Must not be a suffix of publicHost.";
    };
    oidcClientId = lib.mkOption {
      type = lib.types.str;
      default = "headscale";
      description = "Keycloak client id (realm nixit.realm). Redirect URI: https://<publicHost>/oidc/callback.";
    };
    oidcSecretKey = lib.mkOption {
      type = lib.types.str;
      default = "headscale/oidc-client-secret";
      description = "sops key in secrets/common.yaml holding the Keycloak client secret.";
    };
    subnetRouter = {
      routes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "10.20.10.0/24" ];
        description = ''
          LAN routes this host advertises into its own tailnet. When set, a
          tailscale client runs on the host, enrols itself once through a
          one-shot pre-auth key minted locally, and the routes are approved.
        '';
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "infra";
        description = "Headscale user that owns the subnet-router node (created if missing).";
      };
    };
  };

  config = {
    sops.secrets.${hs.oidcSecretKey}.sopsFile = ../../../secrets/common.yaml;

    services.headscale = {
      enable = true;
      address = "0.0.0.0";
      port = 8080;
      settings = {
        server_url = serverUrl;
        dns.base_domain = hs.baseDomain;   # MagicDNS tailnet domain (distinct from server_url)
        dns.magic_dns = true;
        oidc = {
          issuer = "${cfg.authUrl}/realms/${cfg.realm}";
          client_id = hs.oidcClientId;
          client_secret_path = config.sops.secrets.${hs.oidcSecretKey}.path;
          scope = [ "openid" "profile" "email" ];
        };
      };
    };

    # Manage with `headscale` CLI on the host (create users, pre-auth keys, list
    # nodes, approve routes). Clients: `tailscale up --login-server=<serverUrl>`.
    environment.systemPackages = [ config.services.headscale.package ]
      ++ lib.optional (hs.subnetRouter.routes != [ ]) pkgs.jq;

    # Optional subnet router: this host joins its own tailnet and advertises
    # the LAN so remote devices reach hosts that have no tailscale client.
    services.tailscale = lib.mkIf (hs.subnetRouter.routes != [ ]) {
      enable = true;
      useRoutingFeatures = "server";   # ip forwarding + firewall for relayed traffic
      openFirewall = true;
    };

    systemd.services.headscale-subnet-router = lib.mkIf (hs.subnetRouter.routes != [ ]) {
      description = "enrol this host as subnet router in its own headscale";
      after = [ "headscale.service" "tailscaled.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      requires = [ "headscale.service" "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      path = [ config.services.headscale.package config.services.tailscale.package pkgs.jq pkgs.coreutils pkgs.curl ];
      script = ''
        set -eu
        user="${hs.subnetRouter.user}"
        for i in $(seq 1 30); do
          curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1 && break
          sleep 2
        done
        if [ "$(tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo NoState)" != "Running" ]; then
          headscale users list -o json | jq -e --arg u "$user" '.[] | select(.name==$u)' >/dev/null \
            || headscale users create "$user" >/dev/null
          uid=$(headscale users list -o json | jq -r --arg u "$user" '.[] | select(.name==$u) | .id')
          key=$(headscale preauthkeys create --user "$uid" --expiration 15m -o json | jq -r '.key')
          tailscale up --login-server="${serverUrl}" --authkey="$key" \
            --hostname="${config.networking.hostName}" \
            --advertise-routes="${routes}" --accept-dns=false
        fi
        # approve the advertised routes for this node (idempotent)
        self=$(tailscale status --json | jq -r '.Self.HostName')
        nid=$(headscale nodes list -o json | jq -r --arg h "$self" '.[] | select(.name==$h or .given_name==$h) | .id' | head -1)
        [ -n "$nid" ] && headscale nodes approve-routes --identifier "$nid" --routes "${routes}" >/dev/null
      '';
    };
  };
}
