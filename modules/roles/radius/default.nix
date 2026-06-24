# FreeRADIUS with Samba AD backend
# Post-install: copy default raddb config and customize for AD/LDAP
#   cp -r $(nix-store -q --requisites $(which radiusd) | grep freeradius)/etc/raddb /etc/raddb
#   Then edit: mods-enabled/ldap, mods-enabled/eap, clients.conf, sites-enabled/default
{ config, pkgs, ... }: {

  services.freeradius = {
    enable = true;
    # Default: /etc/raddb — copy FreeRADIUS default config there and customize
    # configDir = "/etc/raddb";
  };

  environment.systemPackages = with pkgs; [
    freeradius
  ];

  # Firewall: RADIUS ports
  networking.firewall.allowedUDPPorts = [ 1812 1813 ];

  # sops secrets for RADIUS
  sops.secrets."radius/ldap-bind-password" = {
    sopsFile = ../../../secrets/radius.yaml;
  };
  sops.secrets."radius/shared-secret" = {
    sopsFile = ../../../secrets/radius.yaml;
  };
}
