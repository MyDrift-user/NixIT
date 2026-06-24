{ pkgs, lib, ... }: {

  # ── Display ───────────────────────────────────────────────────────────
  programs.hyprland = {
    enable          = true;
    withUWSM        = true;
    xwayland.enable = true;
  };

  services.displayManager.sddm = {
    enable         = true;
    wayland.enable = false;  # X11 greeter — fixes "ZZ" keyboard layout display
  };
  services.xserver.enable = true;  # Required for SDDM X11 greeter

  # Keyboard layout — XKB for the SDDM/X11 greeter. (console.keyMap is fleet-wide
  # in modules/core; the Hyprland Wayland session sets kb_layout in home.nix.)
  services.xserver.xkb = {
    layout  = "ch";
    variant = "de";
  };

  # ── XDG portal ────────────────────────────────────────────────────────
  xdg.portal = {
    enable       = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  # ── Fonts ─────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    nerd-fonts.caskaydia-cove
    material-symbols
    noto-fonts
    noto-fonts-color-emoji
  ];

  # ── System packages ───────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    wl-clipboard
    grim
    slurp
    networkmanagerapplet
    pavucontrol
    playerctl
    libnotify
    qt6.qtwayland
    libsForQt5.qt5.qtwayland
  ];

  # Enable PAM module for hyprlock so it can authenticate
  security.pam.services.hyprlock = {};
}
