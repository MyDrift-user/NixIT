{
  description = "NixIT - Modular NixOS configurations";

  inputs = {
    # Stable: servers, ISO
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # Unstable: desktop
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning — used by nixos-anywhere for installs
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Push-deploy with automatic rollback (lockout protection)
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Helium browser (not in nixpkgs)
    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # QuickShell rice: bar, notifications, launcher, OSD, dashboard, wallpaper.
    # No `follows` — use caelestia's own pinned quickshell/Qt for a tested build.
    caelestia-shell.url = "github:caelestia-dots/shell";

    caelestia-dots-repo = {
      url = "github:caelestia-dots/caelestia";
      flake = false;
    };

  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, sops-nix, disko, deploy-rs, zen-browser, caelestia-dots-repo, ... }@inputs:
  let
    system = "x86_64-linux";

    # ── Host builders ───────────────────────────────────────────────────
    # Every config is assembled from a small module list. The helpers below
    # keep the three desktop variants and every server identical except for
    # the one or two modules that actually differ.

    mkServer = { host, extraModules ? [ ] }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
          ./modules/core
          ./modules/server
          host
        ] ++ extraModules;
      };

    mkDesktop = de:
      nixpkgs-unstable.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.config.allowUnfree = true; }
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
          ./modules/core
          ./modules/desktop
          ./modules/wm/${de}
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; desktopEnvironment = de; };
            home-manager.users.kuze = import ./home/kuze/home.nix;
          }
          ./hosts/desktop
        ];
      };

    # Single-purpose app server: a name + the service module(s). The shared
    # base (hosts/_common/server-host.nix) supplies disk, user, network.
    mkAppServer = { name, device ? "/dev/sda", services }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
          ./modules/core
          ./modules/server
          ./hosts/_common/server-host.nix
          { networking.hostName = name; nixit.diskDevice = device; }
        ] ++ services;
      };

    # Reachable IPs per host (deploy-rs connects here; bare hostnames don't resolve).
    deployIPs = {
      "svgmdl-keyc-01" = "10.10.20.10"; "svgmdl-forg-01" = "10.10.20.11";
      "svgmdl-exca-01" = "10.10.20.12"; "svgmdl-immi-01" = "10.10.20.13";
      "svgmdl-kasm-01" = "10.10.20.14"; "svgmdl-game-01" = "10.10.20.15";
      "svgmdl-outl-01" = "10.10.20.21"; "svgmdl-outl-02" = "10.10.20.22";
      "svgmdl-outl-03" = "10.10.20.23"; "svgwdc-pape-01" = "10.20.10.10";
      "svgmdl-devl-01" = "10.10.20.40"; "desktop"        = "10.10.20.41";
      "svgmdl-rumi-01" = "10.10.20.16"; "svgmdl-alia-01" = "10.10.20.17";
      "svgwdc-svpn-01" = "10.20.10.2";
    };
    mkNode = name: {
      hostname = deployIPs.${name} or name;
      sshUser  = "root";
      sshOpts  = [ "-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null" ];
      profiles.system.path =
        deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
    };
  in {
    nixosConfigurations = {

      # ── Bootable installer ISO ──────────────────────────────────────
      # Only needed for bare-metal machines you cannot already SSH into.
      # Everything else installs with nixos-anywhere (see README).
      # Build: nix build .#nixosConfigurations.iso.config.system.build.isoImage
      iso = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs self; };
        modules = [ ./iso ];
      };

      # ── Desktops (unstable + home-manager) ──────────────────────────
      desktop       = mkDesktop "hyprland";
      desktop-gnome = mkDesktop "gnome";
      desktop-kde   = mkDesktop "kde";

      # ── Dev workstation VM (GNOME + dev toolchain + Helium, unstable) ─
      "svgmdl-devl-01" = nixpkgs-unstable.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.config.allowUnfree = true; }
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
          ./modules/core
          ./modules/desktop
          ./modules/wm/gnome
          ./modules/dev
          ./hosts/svgmdl-devl-01
        ];
      };

      # ── Servers (stable) ────────────────────────────────────────────
      "mdl-server" = mkServer { host = ./hosts/mdl-server; };

      # FortiGate VPN gateway (father's network) — single VM, joins headscale
      "svgwdc-svpn-01" = mkServer { host = ./hosts/svgwdc-svpn-01; };

      # ── App servers — one service per VM ── STATIC IPs (no DHCP on server VLANs)
      #   MDL → 10.10.20.x (gw .1, VLAN 20) · WDC → 10.20.10.x (gw .1, VLAN 110)
      "svgmdl-keyc-01" = mkAppServer { name = "svgmdl-keyc-01"; services = [ ./modules/services/keycloak   { nixit.ipv4 = "10.10.20.10/24"; } ]; };  # keycloak
      "svgmdl-kasm-01" = mkAppServer { name = "svgmdl-kasm-01"; services = [ ./modules/services/kasm       { nixit.ipv4 = "10.10.20.14/24"; } ]; };  # kasm
      "svgmdl-forg-01" = mkAppServer { name = "svgmdl-forg-01"; services = [ ./modules/services/forgejo    { nixit.ipv4 = "10.10.20.11/24"; } ]; };  # forgejo
      "svgmdl-outl-01" = mkAppServer { name = "svgmdl-outl-01"; services = [ ./modules/services/outline    { nixit.ipv4 = "10.10.20.21/24"; } ]; };  # outline 1
      "svgmdl-outl-02" = mkAppServer { name = "svgmdl-outl-02"; services = [ ./modules/services/outline    { nixit.ipv4 = "10.10.20.22/24"; } ]; };  # outline 2
      "svgmdl-outl-03" = mkAppServer { name = "svgmdl-outl-03"; services = [ ./modules/services/outline    { nixit.ipv4 = "10.10.20.23/24"; } ]; };  # outline 3
      "svgmdl-immi-01" = mkAppServer { name = "svgmdl-immi-01"; services = [ ./modules/services/immich     { nixit.ipv4 = "10.10.20.13/24"; } ]; };  # immich
      "svgmdl-exca-01" = mkAppServer { name = "svgmdl-exca-01"; services = [ ./modules/services/excalidraw { nixit.ipv4 = "10.10.20.12/24"; } ]; };  # excalidash
      "svgmdl-game-01" = mkAppServer { name = "svgmdl-game-01"; services = [ ./modules/services/pelican    { nixit.ipv4 = "10.10.20.15/24"; } ]; };  # pelican game panel

      # Paperless on the WDC (dad's) network — VLAN 110, isolated from MDL
      "svgwdc-pape-01" = mkAppServer { name = "svgwdc-pape-01"; services = [ ./modules/services/paperless  { nixit.ipv4 = "10.20.10.10/24"; nixit.gateway = "10.20.10.1"; } ]; };  # paperless (WDC)

      # ── Not in this deploy batch (kept; add IPs when you bring them up) ──
      "svgmdl-head-01" = mkAppServer { name = "svgmdl-head-01"; services = [ ./modules/services/headscale ]; };  # headscale
      "svgmdl-pape-01" = mkAppServer { name = "svgmdl-pape-01"; services = [ ./modules/services/paperless ]; };  # paperless (MDL — superseded by svgwdc-pape-01)
      "svgmdl-alia-01" = mkAppServer { name = "svgmdl-alia-01"; services = [ ./modules/services/aliasvault { nixit.ipv4 = "10.10.20.17/24"; } ]; }; # aliasvault (alias.lua.li)
      "svgmdl-mood-01" = mkAppServer { name = "svgmdl-mood-01"; services = [ ./modules/services/moodleng { nixit.newt.enable = false; } ]; }; # moodleng
      "svgmdl-rumi-01" = mkAppServer { name = "svgmdl-rumi-01"; services = [ ./modules/services/rumi     { nixit.ipv4 = "10.10.20.16/24"; } ]; }; # rumi (MSP mgmt + customer, built on-VM)
      "svgmdl-fipa-01" = mkAppServer { name = "svgmdl-fipa-01"; services = [ ./modules/services/freeipa  { nixit.newt.enable = false; } ]; }; # FreeIPA
      "svgmdl-sada-01" = mkAppServer { name = "svgmdl-sada-01"; services = [ ./modules/services/samba-ad { nixit.newt.enable = false; } ]; }; # Samba AD

      # Example: add a domain controller by composing modules.
      # "dc01" = mkServer { host = ./hosts/dc01; extraModules = [ ./modules/roles/ad-dc ]; };

      # ── Proxmox VM image (built, not installed — handles its own disk) ─
      # Build:  nix build .#proxmox-image
      # Import: qmrestore ./result/*.vma.zst <vmid> --unique true
      "proxmox-server" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
          sops-nix.nixosModules.sops
          ./modules/core
          ./modules/server
          ./modules/server/proxmox.nix
          ./hosts/mdl-server/users.nix
          {
            networking.hostName = "proxmox-server";
            system.stateVersion = "25.11";
            proxmox.qemuConf = {
              cores  = 2;
              memory = 2048;
              bios   = "ovmf";
              net0   = "virtio=00:00:00:00:00:00,bridge=vmbr0,firewall=1";
              agent  = true;
              boot   = "order=scsi0";
            };
          }
        ];
      };
    };

    # ── Push deployment (deploy-rs) ───────────────────────────────────
    # Deploy from your workstation:  nix run github:serokell/deploy-rs -- .#mdl-server
    # magicRollback + autoRollback are on by default: a config that breaks
    # connectivity is automatically rolled back instead of bricking the host.
    deploy.nodes = {
      "mdl-server"     = mkNode "mdl-server";
      "svgwdc-svpn-01" = mkNode "svgwdc-svpn-01";
      "svgmdl-keyc-01" = mkNode "svgmdl-keyc-01";
      "svgmdl-kasm-01" = mkNode "svgmdl-kasm-01";
      "svgmdl-forg-01" = mkNode "svgmdl-forg-01";
      "svgmdl-pape-01" = mkNode "svgmdl-pape-01";
      "svgmdl-outl-01" = mkNode "svgmdl-outl-01";
      "svgmdl-outl-02" = mkNode "svgmdl-outl-02";
      "svgmdl-outl-03" = mkNode "svgmdl-outl-03";
      "svgwdc-pape-01" = mkNode "svgwdc-pape-01";
      "svgmdl-immi-01" = mkNode "svgmdl-immi-01";
      "svgmdl-head-01" = mkNode "svgmdl-head-01";
      "svgmdl-exca-01" = mkNode "svgmdl-exca-01";
      "svgmdl-alia-01" = mkNode "svgmdl-alia-01";
      "svgmdl-game-01" = mkNode "svgmdl-game-01";
      "svgmdl-mood-01" = mkNode "svgmdl-mood-01";
      "svgmdl-rumi-01" = mkNode "svgmdl-rumi-01";
      "svgmdl-fipa-01" = mkNode "svgmdl-fipa-01";
      "svgmdl-sada-01" = mkNode "svgmdl-sada-01";
      "svgmdl-devl-01" = mkNode "svgmdl-devl-01";
    };

    # `nix flake check` validates every deploy node builds + activation is sane.
    checks = builtins.mapAttrs
      (sys: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib;

    # `nix fmt` formats the whole tree.
    formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;

    # Convenience: nix build .#proxmox-image
    packages.${system}.proxmox-image =
      self.nixosConfigurations."proxmox-server".config.system.build.VMA;
  };
}
