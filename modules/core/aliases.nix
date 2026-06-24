# Core aliases - shared across all machines
{ ... }: {
  programs.bash.shellAliases = {
    # NixOS management (uses current hostname to select config automatically)
    nix-rebuild = "sudo nixos-rebuild switch --flake /etc/nixos";
    nix-update   = "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake /etc/nixos";
    nix-prune    = "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +50 && sudo nix-collect-garbage";
    nix-gens     = "nixos-rebuild list-generations";

    space-scan = "sudo ncdu --exclude '/var/lib/docker' /";

    pls = "sudo $(fc -ln -1)";

    flatpack = "flatpak";

    "cd.." = "cd ..";
    ".."   = "cd ..";
    "..."  = "cd ../../";
    "...." = "cd ../../../";
    "....." = "cd ../../../../";

    mkdir = "mkdir -pv";
    ll    = "ls -alh";
    ports = "netstat -tulanp";
    cls   = "clear";
  };
}
