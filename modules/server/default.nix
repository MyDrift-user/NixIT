# Server module - applied to all NixIT servers
{ config, pkgs, ... }: {
  imports = [
    ./docker
  ];

  environment.systemPackages = with pkgs; [
    dysk
    traceroute
    net-tools
    cloud-utils
  ];

  # Updates are pushed intentionally with deploy-rs (magic rollback), not
  # pulled+rebooted unattended. Bump flake.lock in git -> `deploy .#<host>`.
  # Flip this on only if you want host-side unattended upgrades instead.
  system.autoUpgrade.enable = false;

  # ── Fail2ban ────────────────────────────────────────────────────────
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable  = true;
      maxtime = "168h";
      factor  = "4";
    };
    jails = {
      sshd.settings = {
        enabled  = true;
        port     = "ssh";
        filter   = "sshd[mode=aggressive]";
        maxretry = 3;
        findtime = "10m";
        bantime  = "1h";
      };
    };
  };

  # ── SSH hardening ───────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    ports  = [ 22 ];
    settings = {
      PasswordAuthentication  = false;
      KbdInteractiveAuthentication = false;
      # Key-only root (no password possible) so deploy-rs can activate remotely.
      PermitRootLogin         = "prohibit-password";
      AuthenticationMethods   = "publickey";
      X11Forwarding           = false;
      AllowAgentForwarding    = false;
      AllowTcpForwarding      = false;
      MaxAuthTries            = 3;
      LoginGraceTime          = 30;
      ClientAliveInterval     = 300;
      ClientAliveCountMax     = 2;
      LogLevel                = "VERBOSE";
      # Modern ciphers only
      Ciphers = [ "aes256-gcm@openssh.com" "chacha20-poly1305@openssh.com" ];
      KexAlgorithms = [ "sntrup761x25519-sha512@openssh.com" "curve25519-sha256" "curve25519-sha256@libssh.org" ];
      Macs = [ "hmac-sha2-512-etm@openssh.com" "hmac-sha2-256-etm@openssh.com" ];
    };
    # Ed25519 only — RSA is unnecessary with modern clients
    hostKeys = [
      { path = "/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
    ];
  };

  # Deploy key for deploy-rs (root login is key-only, set above).
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINStVTxixre56N5GRSBCIAQTQYQMbFPfrLsCe2l0rUHe"
  ];

  services.journald.extraConfig = ''
    Storage=persistent
    MaxRetentionSec=90d
    Compress=yes
  '';

  # ── Firewall ────────────────────────────────────────────────────────
  networking.firewall = {
    enable           = true;
    allowedTCPPorts  = [ 22 ];
    allowedUDPPorts  = [ ];
    trustedInterfaces = [ "docker0" ];
    logRefusedConnections = true;
    logReversePathDrops   = true;
    # SSH rate limiting: max 4 new connections per minute per source IP (nftables)
    extraInputRules = ''
      tcp dport 22 ct state new meter ssh-rate { ip saddr limit rate 4/minute burst 4 packets } accept
      tcp dport 22 ct state new drop
    '';
  };

}
