# Immich — photo/video backup. Native services.immich (server + machine-learning
# + Postgres/Redis all auto-provisioned). Public URL: photos.lua.li.
# OIDC is set in Immich's admin UI (it's app-DB state, not declarative).
{ config, ... }:
{
  services.immich = {
    enable = true;
    port = 2283;
    mediaLocation = "/var/lib/immich";   # point at a data disk for big libraries
    openFirewall = true;
  };

  # OIDC (admin UI > Administration > Settings > Authentication > OAuth):
  #   Issuer:  https://mdl.auth.li/realms/main
  #   Client:  immich  (secret = IMMICH_CLIENT_SECRET from keycloak/env)
  # And set the external domain to https://photos.lua.li under Settings > Server.
}
