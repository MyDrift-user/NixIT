# DNS forwarder — split-horizon DNS
# Forwards domain queries to AD DC, everything else upstream
{ config, pkgs, lib, ... }: {

  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [ "0.0.0.0" "::0" ];
        access-control = [
          "10.0.0.0/8 allow"
          "172.16.0.0/12 allow"
          "192.168.0.0/16 allow"
          "127.0.0.0/8 allow"
        ];
        # Disable DNSSEC for internal zones
        module-config = "iterator";
      };
      # Forward internal domain to AD DC
      forward-zone = [
        {
          name = "mydomain.lan.";
          forward-addr = [
            # Replace with your AD DC IP
            "10.0.1.10"
          ];
        }
        {
          name = ".";
          forward-addr = [
            "1.1.1.1"
            "8.8.8.8"
          ];
        }
      ];
    };
  };

  # Firewall: DNS
  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];
}
