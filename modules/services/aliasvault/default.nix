# AliasVault — privacy password manager + built-in email aliasing.
# Single-container image (bundles client/api/admin/SMTP via s6). Web UI behind
# Pangolin at vault.lua.li; SMTP (25/587) is exposed directly so it can receive
# alias mail — point your alias domain's MX records at this host.
#
# No sops secret needed: admin password + data-protection keys are generated on
# first run into /srv/aliasvault/secrets (read them after first boot).
{ config, ... }:
let
  cfg = config.nixit;
in {
  virtualisation.oci-containers.containers.aliasvault = {
    image = "ghcr.io/aliasvault/aliasvault:latest";   # pin a tag in production
    ports = [
      "127.0.0.1:8082:80"      # HTTP -> Pangolin/newt (Pangolin terminates TLS)
      "25:25"                  # SMTP — internet-reachable, set DNS MX here
      "587:587"
    ];
    environment = {
      HOSTNAME = "vault.${cfg.serviceDomain}";
      PUBLIC_REGISTRATION_ENABLED = "false";
      FORCE_HTTPS_REDIRECT = "false";          # Pangolin does HTTPS
      SMTP_TLS_ENABLED = "false";
      PRIVATE_EMAIL_DOMAINS = "";              # your alias mail domain(s), comma-separated
    };
    volumes = [
      "/srv/aliasvault/database:/database"
      "/srv/aliasvault/secrets:/secrets"
      "/srv/aliasvault/logs:/logs"
      "/srv/aliasvault/certificates:/certificates"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 25 587 ];
  systemd.tmpfiles.rules = [ "d /srv/aliasvault 0750 root root -" ];
}
