# AD-integrated SMB file server
{ config, pkgs, ... }: {

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "MYDOMAIN";
        security = "ads";
        "realm" = "MYDOMAIN.LAN";
        "server string" = "NixIT File Server";
        "idmap config * : backend" = "tdb";
        "idmap config * : range" = "3000-7999";
        "idmap config MYDOMAIN : backend" = "ad";
        "idmap config MYDOMAIN : range" = "10000-999999";
        "vfs objects" = "acl_xattr";
        "map acl inherit" = "yes";
      };
      # Share definitions — customize per-host:
      # shared = {
      #   "path" = "/srv/shares/shared";
      #   "read only" = "no";
      #   "valid users" = "@\"MYDOMAIN\\Domain Users\"";
      # };
    };
  };

  # Winbind for AD user resolution
  services.samba.winbindd.enable = true;

  # Domain join tools
  environment.systemPackages = with pkgs; [
    adcli
    samba4Full
    krb5
  ];

  # Kerberos client config
  security.krb5 = {
    enable = true;
    settings.libdefaults = {
      default_realm = "MYDOMAIN.LAN";
      dns_lookup_realm = false;
      dns_lookup_kdc = true;
    };
  };
}
