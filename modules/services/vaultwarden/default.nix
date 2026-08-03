# Vaultwarden: self-hosted Bitwarden-compatible password server.
#
# The whole vault (SQLite db, attachments, RSA signing key) lives in one host
# directory, /srv/vaultwarden/data. Migrating an existing installation is a
# straight directory swap; see README.md.
{ config, ... }:
let
  publicHost = "vault.wdc.gmbh";
in {
  sops.secrets."vaultwarden/env" = {
    sopsFile = ../../../secrets/common.yaml;
    restartUnits = [ "docker-vaultwarden.service" ];
  };

  virtualisation.oci-containers.containers.vaultwarden = {
    # Pinned by digest, not by tag. :latest moves on every upstream release and
    # this container owns everybody's passwords: an unnoticed major bump can
    # migrate the SQLite schema forward with no way back. Digest below is
    # v1.37.1. To bump: docker manifest inspect / docker pull, take the
    # RepoDigest, back up /srv/vaultwarden/data, then edit here.
    image = "vaultwarden/server@sha256:ebdfe70701c60ac0c28c697e787cea767d7972940b786037b29fe0d507f821e8";
    environment = {
      # Deliberately not derived from nixit.serviceDomain: the vault is
      # published on the WDC domain, not the MDL app domain. Must match the URL
      # clients actually use, or WebAuthn and send/attachment links break.
      DOMAIN = "https://${publicHost}";
      # Invite-only. The admin panel creates users; nobody registers themselves.
      SIGNUPS_ALLOWED = "false";
      # Every /admin hit is logged; a brute-force attempt is otherwise silent.
      LOG_LEVEL = "info";
      ROCKET_PORT = "80";
      # No WEBSOCKET_ENABLED: since 1.31.0 the notification socket is served on
      # the main HTTP port and the separate websocket listener was removed.
    };
    # Holds ADMIN_TOKEN (an Argon2id PHC string, not the plaintext).
    environmentFiles = [ config.sops.secrets."vaultwarden/env".path ];
    # Bound to all interfaces so the vault stays reachable on the LAN: the
    # admin panel is blocked at the edge, so /admin is LAN-only by design.
    ports = [ "8086:80" ];
    volumes = [ "/srv/vaultwarden/data:/data" ];
  };

  # The image sets no USER, so vaultwarden runs as uid 0 inside the container
  # and every file it writes is root-owned. Keep the host dir root:root and
  # 0700 to match: a mismatch shows up only as opaque 500s once the SQLite file
  # cannot be opened. A migrated data folder must be chown'd root:root too.
  systemd.tmpfiles.rules = [
    "d /srv/vaultwarden 0755 root root -"
    "d /srv/vaultwarden/data 0700 root root -"
  ];

  networking.firewall.allowedTCPPorts = [ 8086 ];

  nixit.pangolin.resources = [{
    key = "vaultwarden";
    name = "Vaultwarden";
    fullDomain = publicHost;
    port = 8086;
    # No Pangolin SSO gate. Vaultwarden authenticates its own users, and the
    # Bitwarden desktop/mobile/browser clients speak to /api and /identity
    # directly. An interactive login gate in front of those breaks every
    # client that is not a browser.
    sso = false;
    healthPath = "/alive";
  }];
}
