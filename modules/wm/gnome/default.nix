# GNOME desktop environment - system-level configuration
{ pkgs, lib, ... }: {

  # ── Display ───────────────────────────────────────────────────────────
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Keyboard layout (console.keyMap is set fleet-wide in modules/core).
  services.xserver.xkb = {
    layout  = "ch";
    variant = "de";
  };

  # GNOME (Wayland) manages its session layout via dconf, not xserver.xkb — pin it
  # to Swiss German system-wide so every GNOME user gets it (incl. the
  # home-manager-less dev VM), instead of relying on inheritance.
  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/desktop/input-sources" = {
      sources = [ (lib.gvariant.mkTuple [ "xkb" "ch+de" ]) ];
    };
  }];

  # Remove GNOME bloat — core-apps.enable = false removes all bundled apps
  services.gnome.core-apps.enable = false;

  # ── Fonts ─────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    nerd-fonts.caskaydia-cove
    noto-fonts
    noto-fonts-color-emoji
  ];

  # ── System packages ───────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    gnome-tweaks
    catppuccin-gtk
    papirus-icon-theme
    networkmanagerapplet
    pavucontrol
  ];
}
