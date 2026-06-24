# svgmdl-devl-01 — developer workstation VM (GNOME + dev tooling + Helium).
{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ../desktop/users.nix      # reuse the kuze desktop user (sops password + SSH key)
  ];

  networking.hostName = "svgmdl-devl-01";
  system.stateVersion = "25.11";
}
