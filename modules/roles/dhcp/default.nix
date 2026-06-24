# DHCP server (Kea)
# Pairs with AD DNS for dynamic DNS updates
{ config, pkgs, lib, ... }: {

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      # Global parameters
      valid-lifetime = 28800;    # 8 hours
      renew-timer = 14400;       # 4 hours
      rebind-timer = 25200;      # 7 hours

      interfaces-config = {
        interfaces = [ "*" ];    # Override per-host to specific interface
      };

      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };

      # Subnet definition — override per-host
      subnet4 = [
        {
          id = 1;
          subnet = "10.0.1.0/24";
          pools = [
            { pool = "10.0.1.100 - 10.0.1.250"; }
          ];
          option-data = [
            { name = "routers";             data = "10.0.1.1"; }
            { name = "domain-name-servers"; data = "10.0.1.10"; }
            { name = "domain-name";         data = "mydomain.lan"; }
            { name = "ntp-servers";         data = "10.0.1.10"; }
          ];
          # Static reservations
          reservations = [
            # {
            #   hw-address = "aa:bb:cc:dd:ee:ff";
            #   ip-address = "10.0.1.20";
            #   hostname = "printer-office";
            # }
          ];
        }
      ];
    };
  };

  # Firewall: DHCP
  networking.firewall.allowedUDPPorts = [ 67 68 ];
}
