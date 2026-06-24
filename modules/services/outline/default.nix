# Outline (team documentation) — native NixOS module. Provisions local Postgres
# + Redis, and wires OIDC against Keycloak declaratively. Outline requires an
# auth provider, so Keycloak login is mandatory here (no local accounts).
#
# Secrets (sops secrets/common.yaml):
#   outline/secret-key        -> `openssl rand -hex 32`
#   outline/utils-secret      -> `openssl rand -hex 32`
#   outline/oidc-client-secret -> the client secret from the Keycloak "outline" client
{ config, lib, ... }:
let
  cfg = config.nixit;
  kc = "${cfg.authUrl}/realms/${cfg.realm}/protocol/openid-connect";
in {
  # Outline is BSL-licensed (unfree in nixpkgs) — allow just this package.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "outline" ];

  sops.secrets = {
    "outline/secret-key".sopsFile         = ../../../secrets/common.yaml;
    "outline/utils-secret".sopsFile       = ../../../secrets/common.yaml;
    "outline/oidc-client-secret".sopsFile = ../../../secrets/common.yaml;
  };

  services.outline = {
    enable = true;
    publicUrl = "https://docs.${cfg.serviceDomain}";
    port = 3000;
    secretKeyFile   = config.sops.secrets."outline/secret-key".path;
    utilsSecretFile = config.sops.secrets."outline/utils-secret".path;

    storage = {
      storageType  = "local";
      localRootDir = "/var/lib/outline/data";
    };

    oidcAuthentication = {
      clientId = "outline";
      clientSecretFile = config.sops.secrets."outline/oidc-client-secret".path;
      authUrl     = "${kc}/auth";
      tokenUrl    = "${kc}/token";
      userinfoUrl = "${kc}/userinfo";
      displayName = "Keycloak";
      scopes = [ "openid" "profile" "email" ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 3000 ];
}
