# ─────────────────────────────────────────────────────────────────────────
# Declarative container deployments ("docker, managed through Nix")
#
# "OCI" = Open Container Initiative, the vendor-neutral standard that Docker
# and Podman both implement. `virtualisation.oci-containers` is built into
# NixOS (no extra inputs) and turns each container into a managed systemd
# service: pinned image, restart policy, logs in journald, started on boot.
#
# This replaces `docker run` / `docker compose up` + a hand-edited `.env`:
#   - the compose YAML  -> the `containers` attrset below
#   - the `.env` file   -> a sops secret rendered to /run/secrets (never in git)
#   - `docker network`  -> a tiny systemd oneshot (the docker backend doesn't
#                          create networks itself)
#
# The active set is intentionally EMPTY. Copy the worked example below,
# adapt it, and `deploy .#mdl-server`.
# ─────────────────────────────────────────────────────────────────────────
{ config, ... }:
{
  virtualisation.oci-containers.containers = {
    # ── nothing deployed yet — see the template below ──
  };

  # ===========================================================================
  # WORKED EXAMPLE — uncomment, adapt, and add your sops secret (see below).
  # A small two-container stack (app + database) on a private network, with
  # secrets pulled from sops instead of a committed .env file.
  # ===========================================================================
  #
  # 1) Secret env file (replaces .env). Put the *contents* of your .env as a
  #    multiline value under the key `myapp/env` inside an encrypted sops file:
  #        sops secrets/mdl-server.yaml
  #    e.g.
  #        myapp/env: |
  #          POSTGRES_PASSWORD=super-secret
  #          ADMIN_TOKEN=...
  #    sops-nix decrypts it to /run/secrets/myapp-env at activation, root-only.
  #
  # sops.secrets."myapp/env".sopsFile = ../../secrets/mdl-server.yaml;
  #
  # 2) A private docker network so containers reach each other by name
  #    (the equivalent of compose's default network). oci-containers' docker
  #    backend won't create it, so make it once with a oneshot:
  #
  # systemd.services.init-appnet = {
  #   description = "Create the appnet docker network";
  #   after = [ "docker.service" "docker.socket" ];
  #   requires = [ "docker.service" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig.Type = "oneshot";
  #   script = ''
  #     ${config.virtualisation.docker.package}/bin/docker network inspect appnet \
  #       || ${config.virtualisation.docker.package}/bin/docker network create appnet
  #   '';
  # };
  #
  # 3) The containers themselves:
  #
  # virtualisation.oci-containers.containers = {
  #   myapp-db = {
  #     image = "postgres:16.4-alpine";          # always pin a tag, never :latest
  #     volumes = [ "/srv/myapp/db:/var/lib/postgresql/data" ];
  #     environmentFiles = [ config.sops.secrets."myapp/env".path ];
  #     extraOptions = [ "--network=appnet" ];
  #     # no `ports` — only reachable on appnet, never exposed to the LAN
  #   };
  #   myapp = {
  #     image = "ghcr.io/example/myapp:1.8.0";
  #     dependsOn = [ "myapp-db" ];               # start order
  #     ports = [ "127.0.0.1:8080:8080" ];        # bind localhost; front with a reverse proxy
  #     volumes = [ "/srv/myapp/data:/data" ];
  #     environment.DB_HOST = "myapp-db";          # non-secret config inline
  #     environmentFiles = [ config.sops.secrets."myapp/env".path ];
  #     extraOptions = [ "--network=appnet" ];
  #   };
  # };
  #
  # systemd.tmpfiles.rules = [
  #   "d /srv/myapp     0750 root root -"
  #   "d /srv/myapp/db  0750 root root -"
  #   "d /srv/myapp/data 0750 root root -"
  # ];
  #
  # ── Going further ──────────────────────────────────────────────────────
  # - Build your OWN image from source, fully in Nix, no Dockerfile:
  #     pkgs.dockerTools.buildLayeredImage { name = "myapp"; config = { ... }; }
  #   then `image = "myapp:latest"` + `imageFile = self.packages...`.
  # - Bigger stacks with real networks/pods/volumes and auto-update:
  #   quadlet-nix (Podman Quadlet mapped to Nix) or arion (compose-in-Nix).
}
