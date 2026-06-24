# Forgejo git server — native NixOS module (more declarative than Docker:
# config lives here, local Postgres is provisioned automatically with socket
# auth, backups/updates ride the normal rebuild).
{ config, ... }:
let
  host = "git.${config.nixit.serviceDomain}";
in {
  services.forgejo = {
    enable = true;
    database.type = "postgres";       # local PG auto-provisioned (peer auth, no password)
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN   = host;
        ROOT_URL = "https://${host}/";
        HTTP_ADDR = "0.0.0.0";
        HTTP_PORT = 3000;
      };
      service.DISABLE_REGISTRATION = true;   # accounts come via Keycloak (OIDC), not self-signup
      session.COOKIE_SECURE = true;
      "repository".DEFAULT_PRIVATE = "private";
    };
  };

  networking.firewall.allowedTCPPorts = [ 3000 ];

  # OIDC login is runtime state (DB), added once after first boot (run as the
  # forgejo user). Discovery URL = <authUrl>/realms/<realm>/.well-known/openid-configuration:
  #   sudo -u forgejo forgejo --config /var/lib/forgejo/custom/conf/app.ini admin auth add-oauth \
  #     --name keycloak --provider openidConnect --key forgejo --secret <client-secret> \
  #     --auto-discover-url https://mdl.auth.li/realms/main/.well-known/openid-configuration
}
