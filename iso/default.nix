# Minimal bootstrap ISO: boots, enables SSH, ships the repo at /etc/nixos.
# Installation is driven from your workstation with nixos-anywhere
# (scripts/install-host.sh) — the ISO only needs to give an SSH foothold.
# Only needed for bare-metal with no network boot; VMs can use the kexec path.
{ pkgs, modulesPath, self, ... }: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  system.stateVersion = "25.11";
  nix.settings.experimental-features = [ "flakes" "nix-command" ];

  # Swiss German keyboard (console + X)
  console.useXkbConfig = true;
  services.xserver.xkb = {
    layout  = "ch";
    variant = "de";
    options = "kpdl:dot";
  };

  # Serial console for Proxmox/headless installs
  boot.kernelParams = [ "console=ttyS0,115200n8" ];

  # SSH foothold for nixos-anywhere. The ISO is ephemeral, so root login is fine;
  # the host's real (hardened) SSH config takes over once installed.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINStVTxixre56N5GRSBCIAQTQYQMbFPfrLsCe2l0rUHe"
  ];
  users.users.nixos.initialPassword = "nixos";

  # Entire NixIT repo available at /etc/nixos on the ISO
  environment.etc."nixos".source = "${self}";

  environment.systemPackages = with pkgs; [ git curl nano ];

  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
  image.fileName           = "nixit-installer.iso";

  environment.etc."issue".text = ''

    +---------------------------------------------------------+
    |       NixIT - bootstrap ISO (for nixos-anywhere)        |
    |                                                         |
    |  From your workstation:                                 |
    |    ./scripts/install-host.sh <host> root@<this-ip>      |
    |                                                         |
    |  SSH is on (root key + user 'nixos', pw: nixos).        |
    +---------------------------------------------------------+

  '';
}
