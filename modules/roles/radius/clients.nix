# RADIUS client (AP) definitions
# Import this alongside default.nix and customize per-host
{ lib, ... }:
let
  # Define RADIUS clients (access points, switches, etc.)
  # Override this in your host config
  radiusClients = {
    # Example:
    # "ap-office" = {
    #   ipaddr = "10.0.1.10";
    #   secret = "changeme";  # Use sops in production
    #   shortname = "ap-office";
    # };
  };

  # Generate clients.conf content
  clientsConf = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: client: ''
    client ${name} {
        ipaddr = ${client.ipaddr}
        secret = ${client.secret}
        shortname = ${client.shortname}
    }
  '') radiusClients);
in
{
  # clients.conf is managed via configDir in default.nix
  # This module serves as a reference for how to define clients
}
