# Shared base for single-purpose app servers. Collapses disk layout, admin
# user, bootloader and network into one module so each host in flake.nix is
# just a name + a service module. Set per-host bits via the `nixit.*` options.
{ config, lib, ... }:
let
  cfg = config.nixit;
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
  };

  config = {
    system.stateVersion = "25.11";
    networking.useDHCP = true;
    networking.domain = cfg.internalDomain;   # FQDN suffix: <hostname>.doa.lan

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
      "newt/${config.networking.hostName}".sopsFile = ../../secrets/common.yaml;
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
