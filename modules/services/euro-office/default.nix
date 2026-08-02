# Euro-Office — EU-sovereign document server (fork of the ONLYOFFICE Document
# Server), used by Rumi for office document preview and editing.
#
# Rumi talks to this over two paths and BOTH must work:
#   - the browser loads the editor bundle from the public URL
#   - rumi-server fetches the saved document back from the private address,
#     so the engine is reachable on the LAN as well as through Pangolin
#
# `JWT_SECRET` here and `RUMI__DOCUMENTS__JWT_SECRET` on the Rumi VM must be
# the same value; the engine rejects unsigned config with error -8.
{ config, ... }:
let
  cfg = config.nixit;
in {
  sops.secrets."euro-office/env".sopsFile = ../../../secrets/common.yaml;

  virtualisation.oci-containers.containers.euro-office = {
    # Pinned by digest, not by tag: the registry publishes :latest but no
    # version tags, and this engine parses untrusted documents, so it must not
    # change under us between deploys.
    image = "ghcr.io/euro-office/documentserver@sha256:e907996dd6c5d3da7f4961d9d1ea70c5f7c27c71f588a66f20981a2d447e6288";
    environment = {
      JWT_ENABLED = "true";
      JWT_HEADER = "Authorization";
    };
    # Holds JWT_SECRET, shared with rumi-server.
    environmentFiles = [ config.sops.secrets."euro-office/env".path ];
    # Bound to all interfaces, not 127.0.0.1: rumi-server on another VM
    # collects saved documents directly over the LAN.
    ports = [ "8085:80" ];
    # Only the data tree is persisted. Mounting a volume over
    # /var/log/euro-office/documentserver shadows the per-service log
    # directories the image ships, and supervisor refuses to start when
    # `adminpanel/` is missing. Container stdout is captured by journald.
    volumes = [ "/srv/euro-office/data:/var/lib/euro-office/documentserver" ];
  };

  systemd.tmpfiles.rules = [
    "d /srv/euro-office 0750 root root -"
    "d /srv/euro-office/data 0750 root root -"
  ];

  # Only the Rumi VM needs the private path; the public one goes via Pangolin.
  networking.firewall.allowedTCPPorts = [ 8085 ];

  nixit.pangolin.resources = [{
    key = "euro-office";
    name = "Euro-Office";
    fullDomain = "edit.${cfg.serviceDomain}";
    port = 8085;
    # No Pangolin SSO gate. The editor bundle is loaded by an iframe and the
    # engine is called by rumi-server; an interactive login gate in front of
    # either breaks both. The engine authenticates its own callers by JWT.
    sso = false;
    healthPath = "/healthcheck";
  }];
}
