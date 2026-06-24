# KDE Plasma 6 desktop environment - system-level configuration
# Uses Plasma Login Manager (SDDM is deprecated on nixpkgs-unstable)
{ pkgs, lib, ... }: {

  # ── Display ───────────────────────────────────────────────────────────
  services.displayManager.plasma-login-manager.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Keyboard layout (console.keyMap is set fleet-wide in modules/core).
  services.xserver.xkb = {
    layout  = "ch";
    variant = "de";
  };

  # ── Fonts ─────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    nerd-fonts.caskaydia-cove
    noto-fonts
    noto-fonts-color-emoji
  ];

  # ── System packages ───────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    catppuccin-kde
    papirus-icon-theme
    networkmanagerapplet
    pavucontrol
  ];

  # Remove KDE bloat
  environment.plasma6.excludePackages = with pkgs; [
    kdePackages.elisa
  ];
}
