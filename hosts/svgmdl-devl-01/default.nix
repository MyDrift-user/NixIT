# svgmdl-devl-01 — developer workstation VM (GNOME + dev tooling + Helium).
{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ../desktop/users.nix      # reuse the kuze desktop user (sops password + SSH key)
  ];

  networking.hostName = "svgmdl-devl-01";
  # static IP (no DHCP on server VLAN); NM leaves eth0 to scripted networking
  networking.useDHCP = false;
  networking.usePredictableInterfaceNames = false;
  networking.interfaces.eth0.ipv4.addresses = [{ address = "10.10.20.40"; prefixLength = 24; }];
  networking.defaultGateway = "10.10.20.1";
  networking.nameservers = [ "1.1.1.1" "9.9.9.9" ];
  networking.networkmanager.unmanaged = [ "eth0" ];
  services.openssh.enable = true;

  # RDP (Windows mstsc → kuze + password). xrdp serves an Xorg session via
  # xorgxrdp, so the RDP desktop must be X11. GNOME 49 is Wayland-ONLY (it dropped
  # the X11 session), so gnome-session SIGTRAPs under xrdp and the connection drops
  # — use XFCE for the RDP session instead. The local/console session stays GNOME;
  # all dev tools are system-wide, so they work in either. (For GNOME remotely,
  # use Sunshine/Moonlight like the desktop VM.)
  services.xserver.desktopManager.xfce.enable = true;
  services.xrdp = {
    enable = true;
    defaultWindowManager = "xfce4-session";
    openFirewall = true; # opens 3389
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO/pHI10e6RYA3gOw8ptXqvdDyJzkE5eL9ZsCMRVUhv+ mdl-deploy"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFXXSk/BLQQ2E3Q7T9WT5/u91MKELNTFpVvMMh1qJFsG user@DESKTOP-FS4MHQ1"
  ];
  system.stateVersion = "25.11";
}
