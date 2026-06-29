# Shared base for single-purpose app servers. Collapses disk layout, admin
# user, bootloader and network into one module so each host in flake.nix is
# just a name + a service module. Set per-host bits via the `nixit.*` options.
{ config, lib, pkgs, ... }:
let
  cfg = config.nixit;

  # Render this host's Pangolin resources (declared via nixit.pangolin.resources)
  # into a blueprint that `newt` applies (BLUEPRINT_FILE) — so the reverse-proxy
  # mapping + health checks are declarative, scoped to THIS host's newt site.
  # builtins.toJSON output is valid YAML, which is what newt's blueprint parser wants.
  mkResource = r: {
    name = r.name;
    "full-domain" = r.fullDomain;
    protocol = "http";
    ssl = true;
    auth = { "sso-enabled" = r.sso; } // lib.optionalAttrs r.sso { "sso-roles" = [ "Member" ]; };
    targets = [{
      hostname = "localhost";
      method = r.method;
      port = r.port;
      healthcheck = {
        enabled = true;
        hostname = "localhost";
        path = r.healthPath;
        method = "GET";
        port = r.port;
        scheme = r.method; # http/https; newt skips cert verify unless ENFORCE_HC_CERT=true
        status = r.healthStatus;
      };
    }];
  };
  blueprint = {
    "public-resources" =
      builtins.listToAttrs (map (r: { name = r.key; value = mkResource r; }) cfg.pangolin.resources);
  };
  blueprintFile = pkgs.writeText "pangolin-blueprint.json" (builtins.toJSON blueprint);
  haveBlueprint = cfg.newt.enable && cfg.pangolin.resources != [ ];
in {
  options.nixit = {
    diskDevice = lib.mkOption {
      type = lib.types.str;
      default = "/dev/sda";
      description = "Target disk for disko (check with lsblk).";
    };
    internalDomain = lib.mkOption {
      type = lib.types.str;
      default = "doa.lan";
      description = "Internal DNS suffix for VM FQDNs (svgmdl-<svc>-01.<internalDomain>).";
    };
    serviceDomain = lib.mkOption {
      type = lib.types.str;
      default = "lua.li";
      description = "Public domain for user-facing app subdomains (git.<serviceDomain>, docs.<serviceDomain>, …).";
    };
    authUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://mdl.auth.li";
      description = "Public base URL of Keycloak (the OIDC issuer host).";
    };
    realm = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Keycloak realm the apps authenticate against.";
    };
    newt.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run the Pangolin (newt) tunnel. Disable for VMs whose ingress you handle separately.";
    };
    pangolin.resources = lib.mkOption {
      default = [ ];
      description = ''
        Pangolin resources for this host, applied declaratively via the newt
        blueprint (incl. simple HTTP health checks). Each entry maps a public
        domain to a local service port on this VM. Targets are always localhost
        (newt runs --network=host on the service VM).
      '';
      type = lib.types.listOf (lib.types.submodule {
        options = {
          key = lib.mkOption { type = lib.types.str; description = "Blueprint resource key (unique per host)."; };
          name = lib.mkOption { type = lib.types.str; description = "Display name in Pangolin."; };
          fullDomain = lib.mkOption { type = lib.types.str; description = "Public domain, e.g. git.lua.li."; };
          port = lib.mkOption { type = lib.types.int; description = "Local service port on this VM."; };
          method = lib.mkOption { type = lib.types.enum [ "http" "https" ]; default = "http"; description = "Upstream scheme."; };
          sso = lib.mkOption { type = lib.types.bool; default = true; description = "Gate behind Pangolin SSO (Member role). Off for apps with their own auth."; };
          healthPath = lib.mkOption { type = lib.types.str; default = "/"; description = "Health-check path (must return healthStatus)."; };
          healthStatus = lib.mkOption { type = lib.types.int; default = 200; description = "Expected health-check HTTP status."; };
        };
      });
    };
    ipv4 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Static IPv4 in CIDR (e.g. 10.10.20.10/24). null = DHCP. Server VLANs have no DHCP, so set this.";
    };
    gateway = lib.mkOption {
      type = lib.types.str;
      default = "10.10.20.1";
      description = "Default gateway + DNS (used when ipv4 is set). WDC hosts override to 10.20.10.1.";
    };
  };

  config = {
    system.stateVersion = "25.11";
    networking.domain = cfg.internalDomain;   # FQDN suffix: <hostname>.doa.lan
    # Server VLANs are static-only (no DHCP). Set nixit.ipv4 → static eth0; else DHCP.
    networking.usePredictableInterfaceNames = false;   # stable eth0 in the VM
    networking.useDHCP = cfg.ipv4 == null;
    networking.interfaces = lib.mkIf (cfg.ipv4 != null) {
      eth0.ipv4.addresses = [{
        address = lib.head (lib.splitString "/" cfg.ipv4);
        prefixLength = lib.toInt (lib.elemAt (lib.splitString "/" cfg.ipv4) 1);
      }];
    };
    networking.defaultGateway = lib.mkIf (cfg.ipv4 != null) cfg.gateway;
    networking.nameservers   = lib.mkIf (cfg.ipv4 != null) [ "1.1.1.1" "9.9.9.9" ];  # server VLANs: public DNS (firewall allows internet, blocks inter-VLAN)

    boot.loader.systemd-boot.enable      = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.initrd.availableKernelModules = [
      "ahci" "nvme" "sd_mod" "xhci_pci" "usbhid"
      "virtio_pci" "virtio_blk" "virtio_scsi"
    ];

    # Admin user — password from sops, SSH key is the no-lockout safety net.
    # newt's secret is folded in here (one sops.secrets def per module).
    sops.secrets = {
      "kuze/password/${config.networking.hostName}" = {
        sopsFile = ../../secrets/common.yaml;
        neededForUsers = true;
      };
    } // lib.optionalAttrs cfg.newt.enable {
      "newt/${config.networking.hostName}" = {
        sopsFile = ../../secrets/common.yaml;
        restartUnits = [ "docker-newt.service" ];   # re-read creds on change
      };
    };
    users.users.kuze = {
      isNormalUser  = true;
      uid           = 1010;
      extraGroups   = [ "wheel" "docker" ];
      hashedPasswordFile = config.sops.secrets."kuze/password/${config.networking.hostName}".path;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINStVTxixre56N5GRSBCIAQTQYQMbFPfrLsCe2l0rUHe"
      ];
    };

    # Pangolin tunnel — each VM is its own Pangolin "site", reachable via newt
    # with no exposed ports. Host networking lets it reach local service ports
    # (incl. Keycloak on 127.0.0.1:8080). Creds per host: sops key newt/<hostname>.
    # (secret folded into sops.secrets above; disable via nixit.newt.enable=false)
    virtualisation.oci-containers.containers = lib.mkIf cfg.newt.enable {
      newt = {
        image = "fosrl/newt:1";   # pin to an exact patch for production
        environmentFiles = [ config.sops.secrets."newt/${config.networking.hostName}".path ];
        # Declarative reverse-proxy mapping + health checks (nixit.pangolin.resources).
        environment = lib.optionalAttrs haveBlueprint { BLUEPRINT_FILE = "/etc/newt/blueprint.yaml"; };
        volumes = lib.optionals haveBlueprint [ "${blueprintFile}:/etc/newt/blueprint.yaml:ro" ];
        extraOptions = [ "--network=host" ];
      };
    };

    disko.devices.disk.main = {
      device = cfg.diskDevice;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 10;
            type = "EF00";
            size = "512M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          swap = {
            priority = 20;
            size = "8G";
            content.type = "swap";
          };
          root = {
            priority = 30;
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-L" "nixos" "-f" ];
              subvolumes = {
                "@"     = { mountpoint = "/";        mountOptions = [ "compress=zstd:1" "noatime" ]; };
                "@home" = { mountpoint = "/home";    mountOptions = [ "compress=zstd:1" "noatime" ]; };
                "@nix"  = { mountpoint = "/nix";     mountOptions = [ "compress=zstd:1" "noatime" ]; };
                "@log"  = { mountpoint = "/var/log"; mountOptions = [ "compress=zstd:1" "noatime" ]; };
              };
            };
          };
        };
      };
    };
  };
}
