# Print server (CUPS + Samba)
# AD-integrated printing — users authenticate via domain credentials
{ config, pkgs, lib, ... }: {

  # CUPS print server
  services.printing = {
    enable = true;
    listenAddresses = [ "*:631" ];
    allowFrom = [ "all" ];
    browsing = true;
    defaultShared = true;
    drivers = with pkgs; [
      gutenprint
      hplip
    ];
    extraConf = ''
      # Require authentication for admin operations
      <Location /admin>
        AuthType Default
        Require user @SYSTEM
      </Location>

      # Allow remote administration
      <Location /admin/conf>
        AuthType Default
        Require user @SYSTEM
      </Location>
    '';
  };

  # Avahi for printer discovery (mDNS/DNS-SD)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # Share printers via Samba (for Windows clients)
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "printing" = "cups";
        "printcap name" = "cups";
        "load printers" = "yes";
        "cups options" = "raw";
      };
      printers = {
        "comment" = "All Printers";
        "path" = "/var/spool/samba";
        "printable" = "yes";
        "guest ok" = "no";
        "browseable" = "no";
      };
      "print$" = {
        "comment" = "Printer Drivers";
        "path" = "/var/lib/samba/drivers";
        "browseable" = "yes";
        "read only" = "yes";
        "guest ok" = "no";
      };
    };
  };

  # Ensure spool directory exists
  systemd.tmpfiles.rules = [
    "d /var/spool/samba 1777 root root -"
    "d /var/lib/samba/drivers 0755 root root -"
  ];

  # Firewall: CUPS + IPP
  networking.firewall.allowedTCPPorts = [ 631 ];
  networking.firewall.allowedUDPPorts = [ 631 5353 ];
}
