# Maler Caroli — static marketing site (nginx in a container). Public, no SSO.
# Single-page site (Vite build served by nginx); the image is published from the
# caroli repo. newt runs in front (--network=host) and tunnels malercaroli.lua.li
# to this container on localhost. Pangolin resource is declared in flake.nix.
{ ... }:
{
  virtualisation.oci-containers.containers.caroli = {
    image = "ghcr.io/mydrift-user/malercaroli:1.7.0";   # pin a digest for prod
    ports = [ "127.0.0.1:8080:80" ];
    # No env/DB. For the Supabase-backed editor, bake VITE_SUPABASE_* at image
    # build time (docker --build-arg) and publish a new tag; nothing changes here.
  };
}
