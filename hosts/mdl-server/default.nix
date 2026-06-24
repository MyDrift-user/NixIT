# MDL server - host-specific configuration
{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ./network.nix
    ./users.nix
    ./containers.nix
  ];

  system.stateVersion = "25.11";
}
