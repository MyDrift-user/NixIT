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

    # rumi agent — relay role (private flake, buildRustPackage)
    rumi.url = "github:MyDrift-user/rumi?dir=installer/nix";

  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, sops-nix, disko, deploy-rs, zen-browser, caelestia-dots-repo, ... }@inputs:
  let
    system = "x86_64-linux";

    # Host builders: assemble each config from a small module list.

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
            # back up pre-existing files instead of failing HM activation —
            # a stray fuzzel.ini was breaking home-manager-<user>.service every boot
            home-manager.backupFileExtension = "hmbak";
            home-manager.extraSpecialArgs = { inherit inputs; desktopEnvironment = de; };
            home-manager.users.kuze = import ./home/kuze/home.nix;
          }
          ./hosts/desktop
        ];
      };

    # Single-purpose app server: name + service module(s); shared base supplies disk, user, network.
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
      "svgmdl-moni-01" = "10.10.20.18"; "svgmdl-caro-01" = "10.10.20.19";
      "svgwdc-svpn-01" = "10.20.10.2";
      "svgwdc-rlay-01" = "10.20.10.20";
      "svgmdl-eoff-01" = "10.10.20.24";
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

      # Installer ISO — only for bare-metal you can't already SSH into; else nixos-anywhere.
      # Build: nix build .#nixosConfigurations.iso.config.system.build.isoImage
      iso = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs self; };
        modules = [ ./iso ];
      };

      # Desktops (unstable + home-manager)
      desktop       = mkDesktop "hyprland";
      desktop-gnome = mkDesktop "gnome";
      desktop-kde   = mkDesktop "kde";

      # Dev workstation VM (GNOME + dev toolchain + Helium, unstable)
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

      # Servers (stable)
      "mdl-server" = mkServer { host = ./hosts/mdl-server; };

      # FortiGate VPN gateway (father's network) — single VM, joins headscale
      "svgwdc-svpn-01" = mkServer { host = ./hosts/svgwdc-svpn-01; };

      # App servers — one service per VM; static IPs (no DHCP on server VLANs).
      #   MDL → 10.10.20.x (gw .1, VLAN 20) · WDC → 10.20.10.x (gw .1, VLAN 110)
      "svgmdl-keyc-01" = mkAppServer { name = "svgmdl-keyc-01"; services = [ ./modules/services/keycloak   { nixit.ipv4 = "10.10.20.10/24"; nixit.pangolin.resources = [{ key = "keycloak"; name = "Keycloak"; fullDomain = "mdl.auth.li"; port = 8080; sso = false; healthPath = "/realms/master"; }]; } ]; };  # keycloak (no Pangolin SSO — self-protects; required for OIDC token exchange)
      "svgmdl-kasm-01" = mkAppServer { name = "svgmdl-kasm-01"; services = [ ./modules/services/kasm       { nixit.ipv4 = "10.10.20.14/24"; nixit.pangolin.resources = [{ key = "kasm"; name = "Kasm"; fullDomain = "office.lua.li"; port = 443; method = "https"; sso = false; healthPath = "/api/__healthcheck"; }]; } ]; };  # kasm (own auth)
      "svgmdl-forg-01" = mkAppServer { name = "svgmdl-forg-01"; services = [ ./modules/services/forgejo    { nixit.ipv4 = "10.10.20.11/24"; nixit.pangolin.resources = [{ key = "forgejo"; name = "Forgejo"; fullDomain = "git.lua.li"; port = 3000; sso = false; healthPath = "/api/healthz"; }]; } ]; };  # forgejo (own auth)
      "svgmdl-outl-01" = mkAppServer { name = "svgmdl-outl-01"; services = [ ./modules/services/outline    { nixit.ipv4 = "10.10.20.21/24"; nixit.pangolin.resources = [{ key = "outline"; name = "Outline"; fullDomain = "docs.lua.li"; port = 3000; sso = false; healthPath = "/_health"; }]; } ]; };  # outline 1
      "svgmdl-outl-02" = mkAppServer { name = "svgmdl-outl-02"; services = [ ./modules/services/outline    { nixit.ipv4 = "10.10.20.22/24"; nixit.outlineUrl = "https://idpa.mydrift.dev"; nixit.pangolin.resources = [{ key = "outline"; name = "Outline IDPA"; fullDomain = "idpa.mydrift.dev"; port = 3000; sso = true; healthPath = "/_health"; }]; } ]; };  # outline 2 → idpa.mydrift.dev (IDPA)
      "svgmdl-outl-03" = mkAppServer { name = "svgmdl-outl-03"; services = [ ./modules/services/outline    { nixit.ipv4 = "10.10.20.23/24"; } ]; };  # outline 3
      "svgmdl-immi-01" = mkAppServer { name = "svgmdl-immi-01"; services = [ ./modules/services/immich     { nixit.ipv4 = "10.10.20.13/24"; nixit.pangolin.resources = [{ key = "immich"; name = "Immich"; fullDomain = "photos.lua.li"; port = 2283; sso = false; healthPath = "/api/server/ping"; }]; nixit.nasStorage = { ip = "10.10.30.13"; mounts = [{ export = "/volume1/MDL/immich"; mountPoint = "/var/lib/immich"; }]; }; } ]; };  # immich (own auth/OIDC; media on NAS)
      "svgmdl-exca-01" = mkAppServer { name = "svgmdl-exca-01"; services = [ ./modules/services/excalidraw { nixit.ipv4 = "10.10.20.12/24"; nixit.pangolin.resources = [{ key = "excalidash"; name = "ExcaliDash"; fullDomain = "draw.lua.li"; port = 6767; sso = true; healthPath = "/health"; }]; } ]; };  # excalidash
      "svgmdl-game-01" = mkAppServer { name = "svgmdl-game-01"; services = [ ./modules/services/pelican    { nixit.ipv4 = "10.10.20.15/24"; nixit.pangolin.resources = [{ key = "pelican"; name = "Pelican"; fullDomain = "game.lua.li"; port = 8085; sso = true; healthPath = "/up"; }]; } ]; };  # pelican game panel
      "svgmdl-caro-01" = mkAppServer { name = "svgmdl-caro-01"; services = [ ./modules/services/caroli     { nixit.ipv4 = "10.10.20.19/24"; nixit.pangolin.resources = [
        { key = "caroli"; name = "Maler Caroli"; fullDomain = "malercaroli.lua.li"; port = 8080; sso = false; healthPath = "/"; }  # public marketing site
        { key = "caro-db"; name = "Caroli Supabase"; fullDomain = "caro-db.lua.li"; port = 8000; sso = false; healthPath = "/auth/v1/health"; }  # self-hosted Supabase gateway (editor backend)
      ]; } ]; };  # caroli — site + self-hosted Supabase editor backend

      # Paperless on the WDC (dad's) network — VLAN 110, isolated from MDL
      "svgwdc-pape-01" = mkAppServer { name = "svgwdc-pape-01"; services = [ ./modules/services/paperless  { nixit.ipv4 = "10.20.10.10/24"; nixit.gateway = "10.20.10.1"; nixit.pangolin.resources = [{ key = "paperless"; name = "Paperless"; fullDomain = "paper.lua.li"; port = 28981; sso = true; healthPath = "/accounts/login/"; }]; nixit.nasStorage = { ip = "10.10.30.110"; mounts = [{ export = "/volume1/MDL/paperless"; mountPoint = "/var/lib/paperless/media"; }]; }; } ]; };  # paperless (WDC; documents on NAS — sqlite db stays local)
      "svgwdc-rlay-01" = mkAppServer { name = "svgwdc-rlay-01"; services = [ ./modules/services/rumi-relay { nixit.ipv4 = "10.20.10.20/24"; nixit.gateway = "10.20.10.1"; nixit.newt.enable = false; } ]; };  # rumi PXE relay (WDC net; LAN-only, no Pangolin)

      # Not in this deploy batch — add IPs when you bring them up
      "svgmdl-head-01" = mkAppServer { name = "svgmdl-head-01"; services = [ ./modules/services/headscale ]; };  # headscale
      "svgmdl-pape-01" = mkAppServer { name = "svgmdl-pape-01"; services = [ ./modules/services/paperless ]; };  # paperless (MDL — superseded by svgwdc-pape-01)
      "svgmdl-alia-01" = mkAppServer { name = "svgmdl-alia-01"; services = [ ./modules/services/aliasvault { nixit.ipv4 = "10.10.20.17/24"; } ]; }; # aliasvault (alias.lua.li)
      "svgmdl-mood-01" = mkAppServer { name = "svgmdl-mood-01"; services = [ ./modules/services/moodleng { nixit.newt.enable = false; } ]; }; # moodleng
      "svgmdl-rumi-01" = mkAppServer { name = "svgmdl-rumi-01"; services = [ ./modules/services/rumi     { nixit.ipv4 = "10.10.20.16/24"; nixit.pangolin.resources = [
        { key = "rumi-mgmt"; name = "Rumi MGMT"; fullDomain = "rumi.lua.li"; port = 8080; sso = false; healthPath = "/"; }  # own auth — no Pangolin gate
        { key = "rumi-customer"; name = "Rumi Customer WDC"; fullDomain = "service.wdconsulting.ch"; port = 8090; sso = false; healthPath = "/"; }  # customer-facing: own auth, no Pangolin SSO
        { key = "mesh"; name = "Rumi Mesh (Headscale)"; fullDomain = "mesh.lua.li"; port = 8091; sso = false; healthPath = "/health"; }  # Headscale coord server — direct (device auth); WS upgrades /ts2021 /derp pass through Traefik
      ]; } ]; }; # rumi (MSP mgmt + customer + Headscale mesh, built on-VM)
      # euro-office document engine — Rumi document preview/edit.
      # newt is off until a Pangolin site exists for this host (creating one
      # needs the TOTP-gated dashboard). Until then the engine is LAN-only on
      # 10.10.20.24:8085; flip newt.enable back on and redeploy to publish
      # edit.lua.li, which the service module already declares.
      "svgmdl-eoff-01" = mkAppServer { name = "svgmdl-eoff-01"; services = [ ./modules/services/euro-office { nixit.ipv4 = "10.10.20.24/24"; nixit.newt.enable = false; } ]; };
      "svgmdl-moni-01" = mkAppServer { name = "svgmdl-moni-01"; services = [ ./modules/services/monitoring { nixit.ipv4 = "10.10.20.18/24"; nixit.pangolin.resources = [{ key = "gatus"; name = "Status"; fullDomain = "status.lua.li"; port = 8080; sso = false; healthPath = "/health"; hostname = "127.0.0.1"; }]; networking.interfaces.eth1.ipv4.addresses = [{ address = "10.10.10.30"; prefixLength = 24; }]; networking.interfaces.eth2.ipv4.addresses = [{ address = "10.10.30.30"; prefixLength = 24; }]; networking.interfaces.eth3.ipv4.addresses = [{ address = "10.20.10.30"; prefixLength = 24; }]; } ]; }; # monitoring — Gatus; multi-homed eth0=vlan20/eth1=vlan10/eth2=vlan30/eth3=vlan110 so probes reach every VLAN
      "svgmdl-fipa-01" = mkAppServer { name = "svgmdl-fipa-01"; services = [ ./modules/services/freeipa  { nixit.newt.enable = false; } ]; }; # FreeIPA
      "svgmdl-sada-01" = mkAppServer { name = "svgmdl-sada-01"; services = [ ./modules/services/samba-ad { nixit.newt.enable = false; } ]; }; # Samba AD

      # Example: add a domain controller by composing modules.
      # "dc01" = mkServer { host = ./hosts/dc01; extraModules = [ ./modules/roles/ad-dc ]; };

      # Proxmox VM image (built, not installed — handles its own disk)
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

    # Push deployment (deploy-rs): nix run github:serokell/deploy-rs -- .#mdl-server
    # magicRollback + autoRollback on by default — a config that breaks connectivity rolls back.
    deploy.nodes = {
      "mdl-server"     = mkNode "mdl-server";
      "svgwdc-svpn-01" = mkNode "svgwdc-svpn-01";
      "svgwdc-rlay-01" = mkNode "svgwdc-rlay-01";
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
      "svgmdl-eoff-01" = mkNode "svgmdl-eoff-01";
      "svgmdl-exca-01" = mkNode "svgmdl-exca-01";
      "svgmdl-alia-01" = mkNode "svgmdl-alia-01";
      "svgmdl-game-01" = mkNode "svgmdl-game-01";
      "svgmdl-caro-01" = mkNode "svgmdl-caro-01";
      "svgmdl-mood-01" = mkNode "svgmdl-mood-01";
      "svgmdl-rumi-01" = mkNode "svgmdl-rumi-01";
      "svgmdl-moni-01" = mkNode "svgmdl-moni-01";
      "svgmdl-fipa-01" = mkNode "svgmdl-fipa-01";
      "svgmdl-sada-01" = mkNode "svgmdl-sada-01";
      "svgmdl-devl-01" = mkNode "svgmdl-devl-01";
      "desktop"        = mkNode "desktop";
    };

    # `nix flake check` validates every deploy node builds + activation is sane.
    checks = builtins.mapAttrs
      (sys: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib;

    formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;

    # Convenience: nix build .#proxmox-image
    packages.${system}.proxmox-image =
      self.nixosConfigurations."proxmox-server".config.system.build.VMA;
  };
}
