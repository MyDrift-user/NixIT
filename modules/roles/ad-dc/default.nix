# Samba Active Directory Domain Controller
# Includes: Samba AD DC, internal DNS, NTP (Chrony), internal CA (step-ca)
# Admin only needs to override: realm, workgroup, netbios name, dns forwarder
{ config, lib, pkgs, ... }:
let
  sambaPackage = (pkgs.samba.override {
    enableLDAP = true;
    enableMDNS = true;
    enableDomainController = true;
  }).overrideAttrs (finalAttrs: prevAttrs: {
    pythonPath = with pkgs; [
      python3Packages.dnspython
      python3Packages.markdown
      tdb ldb talloc
    ];
  });
in
{

  # ── Samba AD DC ────────────────────────────────────────────────────────

  services.samba = {
    enable = true;
    package = sambaPackage;
    # Disable individual daemons — the DC binary runs its own
    smbd.enable = false;
    nmbd.enable = false;
    winbindd.enable = false;
    # Override these values in your host config
    settings = {
      global = {
        "server role" = "active directory domain controller";
        "realm" = "MYDOMAIN.LAN";
        "workgroup" = "MYDOMAIN";
        "netbios name" = "DC01";
        "dns forwarder" = "1.1.1.1";
        "idmap_ldb:use rfc2307" = "yes";
        "tls enabled" = "yes";
        "tls keyfile" = "/var/lib/samba/private/tls/key.pem";
        "tls certfile" = "/var/lib/samba/private/tls/cert.pem";
        "tls cafile" = "/var/lib/samba/private/tls/ca.pem";
        # Allow root — needed for AD DC provisioning and operation
        "invalid users" = lib.mkForce [];
        security = "auto";
      };
      sysvol = {
        "path" = "/var/lib/samba/sysvol";
        "read only" = "no";
      };
      netlogon = {
        "path" = "/var/lib/samba/sysvol/mydomain.lan/scripts";
        "read only" = "no";
      };
    };
  };

  # Custom systemd service for the DC binary
  systemd.services.samba-dc = {
    description = "Samba AD Domain Controller";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${sambaPackage}/sbin/samba --foreground --no-process-group";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      LimitNOFILE = 16384;
      PIDFile = "/run/samba.pid";
      Type = "notify";
      NotifyAccess = "all";
    };
    unitConfig.RequiresMountsFor = "/var/lib/samba";
  };

  # Kerberos client config pointing to local DC
  security.krb5 = {
    enable = true;
    settings.libdefaults = {
      default_realm = "MYDOMAIN.LAN";
      dns_lookup_realm = false;
      dns_lookup_kdc = true;
    };
  };

  # Ensure Samba directories exist (systemd-tmpfiles, not activationScripts)
  systemd.tmpfiles.rules = [
    "d /var/lib/samba 0755 root root -"
    "d /var/lib/samba/private 0700 root root -"
    "d /var/lib/samba/private/tls 0700 root root -"
    "d /var/lib/samba/lock 0755 root root -"
    "d /var/lib/samba/sysvol 0755 root root -"
  ];

  # sops secrets for AD admin password
  sops.secrets."ad/admin-password" = {
    sopsFile = ../../../secrets/ad-dc.yaml;
  };

  # ── DNS (Samba internal) ───────────────────────────────────────────────

  services.resolved.enable = false;
  networking.nameservers = [ "127.0.0.1" ];
  # Ensure resolv.conf points to local Samba DNS
  environment.etc."resolv.conf".text = lib.mkForce ''
    nameserver 127.0.0.1
  '';

  # ── NTP (Chrony) ──────────────────────────────────────────────────────
  # AD DC is the authoritative time source — Kerberos requires accurate time

  services.chrony = {
    enable = true;
    extraConfig = ''
      # Allow NTP clients from local networks
      allow 10.0.0.0/8
      allow 172.16.0.0/12
      allow 192.168.0.0/16

      # Serve time even when not synced (stratum 10 as fallback)
      local stratum 10

      # Log statistics
      log tracking measurements statistics
      logdir /var/log/chrony
    '';
    servers = [
      "0.ch.pool.ntp.org"
      "1.ch.pool.ntp.org"
      "2.ch.pool.ntp.org"
      "3.ch.pool.ntp.org"
    ];
  };

  services.timesyncd.enable = false;

  # ── Internal CA (step-ca) ─────────────────────────────────────────────
  # Issues TLS certs for LDAPS, RADIUS EAP, and internal services

  services.step-ca = {
    enable = true;
    address = "0.0.0.0";
    port = 8443;
    openFirewall = true;
    settings = {
      root = "/var/lib/step-ca/certs/root_ca.crt";
      crt = "/var/lib/step-ca/certs/intermediate_ca.crt";
      key = "/var/lib/step-ca/secrets/intermediate_ca_key";
      dnsNames = [ "ca.mydomain.lan" "localhost" ];
      logger.format = "text";
      db = {
        type = "badgerv2";
        dataSource = "/var/lib/step-ca/db";
      };
      authority = {
        provisioners = [
          {
            type = "ACME";
            name = "acme";
          }
          {
            type = "JWK";
            name = "admin";
          }
        ];
        claims = {
          minTLSCertDuration = "5m";
          maxTLSCertDuration = "8760h";    # 1 year
          defaultTLSCertDuration = "720h"; # 30 days
        };
      };
      tls = {
        cipherSuites = [
          "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
          "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
          "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
          "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        ];
        minVersion = 1.2;
        maxVersion = 1.3;
      };
    };
  };

  # step-ca uses DynamicUser — can't set owner directly
  sops.secrets."ca/intermediate-password" = {
    sopsFile = ../../../secrets/ad-dc.yaml;
    path = "/run/secrets/ca-intermediate-password";
    mode = "0444";
  };

  services.step-ca.intermediatePasswordFile = lib.mkForce "/run/secrets/ca-intermediate-password";

  # ── Firewall ──────────────────────────────────────────────────────────
  # AD DC + DNS + NTP (step-ca uses openFirewall)
  networking.firewall.allowedTCPPorts = [ 53 88 135 139 389 445 464 636 3268 3269 ];
  networking.firewall.allowedUDPPorts = [ 53 88 123 137 138 389 464 ];

  # ── Packages ──────────────────────────────────────────────────────────
  environment.systemPackages = [
    sambaPackage
    pkgs.krb5
    pkgs.openldap
    pkgs.step-cli
    pkgs.step-ca
  ];
}
