# Advanced hardening - CIS-aligned security baseline
{ lib, ... }: {

  # Use nftables (modern replacement for iptables)
  networking.nftables.enable = true;

  # dbus-broker (faster, more secure than classic dbus-daemon)
  services.dbus.implementation = "broker";

  # Additional sysctl hardening (extends security.nix)
  boot.kernel.sysctl = {
    "kernel.kexec_load_disabled"             = 1;
    "net.ipv4.tcp_timestamps"                = 0;
    "net.ipv4.conf.all.accept_source_route"  = 0;
    "net.ipv6.conf.all.accept_source_route"  = 0;
    "net.ipv4.conf.all.secure_redirects"     = 0;
    "fs.protected_hardlinks"                 = 1;
    "fs.protected_symlinks"                  = 1;
    "fs.protected_fifos"                     = 2;
    "fs.protected_regular"                   = 2;
  };

  # Login limits (core=0 is in security.nix)
  security.pam.loginLimits = [
    { domain = "*"; type = "hard"; item = "maxlogins"; value = "10"; }
  ];

  # Sudo requires wheel group membership (defense in depth)
  security.sudo.execWheelOnly = true;
}
