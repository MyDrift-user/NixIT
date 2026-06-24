# Desktop workstation - host-specific configuration
{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ./network.nix
    ./users.nix
    ./platform.nix
  ];

  system.stateVersion = "25.11";
}
