# xrdp multi-session host with GNOME desktop sessions
# Each user gets an isolated GNOME session via RDP (port 3389)
{ config, pkgs, lib, ... }: {

  services.xrdp = {
    enable = true;
    defaultWindowManager = "${pkgs.gnome-session}/bin/gnome-session";
    openFirewall = true;
  };

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Remove GNOME bloat for server use
  services.gnome.core-apps.enable = false;

  # Disable autologin (required for multi-session)
  services.displayManager.autoLogin.enable = false;

  # Fonts for RDP sessions
  fonts.packages = with pkgs; [
    nerd-fonts.caskaydia-cove
    noto-fonts
    noto-fonts-color-emoji
  ];

  environment.systemPackages = with pkgs; [
    gnome-tweaks
    papirus-icon-theme
  ];
}
