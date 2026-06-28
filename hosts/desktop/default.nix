# Desktop workstation - host-specific configuration
{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ./network.nix
    ./users.nix
    ./platform.nix
    ./remote.nix      # Sunshine (Moonlight) streaming of the Hyprland session
  ];

  system.stateVersion = "25.11";
}
