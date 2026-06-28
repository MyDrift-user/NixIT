# Remote access to the Hyprland desktop.
#
# RDP (xrdp) can't drive a Wayland/Hyprland session, so instead we stream the
# REAL caelestia session with Sunshine and connect from the Moonlight client
# (Windows/Android/etc.). Sunshine captures Hyprland's output (KMS/wlr-screencopy)
# and software-encodes it (this VM has no HW encoder) — low latency on a LAN.
{ ... }: {
  services.sunshine = {
    enable = true;
    openFirewall = true; # 47984-48010 TCP/UDP + the 47989/47990 web/HTTPS ports
    capSysAdmin = true; # CAP_SYS_ADMIN wrapper for the Wayland/KMS capture path
    autoStart = true; # systemd --user service, bound to graphical-session.target
  };

  # Sunshine can only capture a LIVE session, so log kuze into Hyprland on boot —
  # otherwise the box sits at the SDDM greeter with nothing to stream. This VM
  # exists for remote use; console autologin is acceptable on the LAN, and remote
  # access still requires Moonlight pairing (PIN) + the Sunshine web-UI admin login.
  services.displayManager.autoLogin = {
    enable = true;
    user = "kuze";
  };
  services.displayManager.defaultSession = "hyprland";

  # Let Sunshine (runs as kuze, who is in `input`) open /dev/uinput so Moonlight
  # can drive the mouse/keyboard. hardware.uinput's default rule doesn't grant it
  # here (the node stays root:root 0600), so set group+mode explicitly.
  services.udev.extraRules = ''
    KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
  '';
}
