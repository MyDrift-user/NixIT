{ ... }: {
  imports = [
    ./aliases.nix
    ./packages.nix
    ./security.nix
    ./hardening.nix
    ./sops.nix
  ];

  # Every MDL host is a Proxmox VM — run the guest agent so PVE can fs-freeze
  # for filesystem-consistent backups (vzdump was logging "agent configured but
  # not running" and skipping the freeze) plus graceful shutdown + IP reporting.
  services.qemuGuest.enable = true;
}
