# Desktop module - applied to all NixIT workstations
{ pkgs, lib, ... }: {

  # ── Audio ─────────────────────────────────────────────────────────────
  services.pulseaudio.enable = false;
  security.rtkit.enable      = true;
  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
  };

  # ── Bluetooth ─────────────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  services.blueman.enable   = true;

  # ── Graphics ──────────────────────────────────────────────────────────
  hardware.graphics = {
    enable      = true;
    enable32Bit = true;
  };


  # ── File manager ──────────────────────────────────────────────────────
  programs.thunar.enable = true;
  services.gvfs.enable   = true;

  # ── Polkit ────────────────────────────────────────────────────────────
  security.polkit.enable = true;
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy    = [ "graphical-session.target" ];
    wants       = [ "graphical-session.target" ];
    after       = [ "graphical-session.target" ];
    serviceConfig = {
      Type      = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart   = "on-failure";
    };
  };

  programs.dconf.enable    = true;
  services.printing.enable = true;

  # ── Networking ────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;
  networking.firewall.enable       = true;

  # KVM guest agent (these desktops run as Proxmox VMs; harmless on bare metal).
  services.qemuGuest.enable = true;

  # Bootloader is configured per-host by the installer (boot.nix)
}
