{ ... }: {
  imports = [
    ./aliases.nix
    ./packages.nix
    ./security.nix
    ./hardening.nix
    ./sops.nix
  ];
}
