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

  # Deploy keys for deploy-rs / ssh.exe (root login is key-only, set above).
  # mdl_deploy is the passwordless admin key stored in mdl-infra/deployments/_admin/
  # (the NStVTxix private key was lost and IFXXSk is passphrase-encrypted, so this
  # is the usable one for non-interactive deploys). See deployments/_admin/README.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINStVTxixre56N5GRSBCIAQTQYQMbFPfrLsCe2l0rUHe"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFXXSk/BLQQ2E3Q7T9WT5/u91MKELNTFpVvMMh1qJFsG user@DESKTOP-FS4MHQ1"  # WSL deploy host (passphrase)
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO/pHI10e6RYA3gOw8ptXqvdDyJzkE5eL9ZsCMRVUhv+ mdl-deploy"  # passwordless admin deploy key
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
