# Minimal bootstrap ISO for nixos-anywhere: SSH foothold + repo at /etc/nixos.
# Bare-metal only (no network boot); VMs use the kexec path.
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

  # server VLANs have no DHCP — for an install give the target a temp static IP via
  # the serial console (qm terminal), or bake one in here + rebuild the ISO, then revert
  #
  # To bake one in for an install, uncomment and rebuild. eth0 is the right
  # name because the installed hosts set usePredictableInterfaceNames = false
  # and the ISO must match, or the address lands on an interface that does not
  # exist. 10.10.20.99 is free on the MDL server VLAN.
  #
  #   networking.usePredictableInterfaceNames = false;
  #   networking.useDHCP = false;
  #   networking.interfaces.eth0.ipv4.addresses =
  #     [{ address = "10.10.20.99"; prefixLength = 24; }];
  #   networking.defaultGateway = "10.10.20.1";
  #   networking.nameservers = [ "10.10.20.1" ];

  # SSH foothold for nixos-anywhere; ISO is ephemeral so root login is fine
  # (the installed host's hardened SSH config takes over).
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINStVTxixre56N5GRSBCIAQTQYQMbFPfrLsCe2l0rUHe"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO/pHI10e6RYA3gOw8ptXqvdDyJzkE5eL9ZsCMRVUhv+ mdl-deploy"
  ];
  users.users.nixos.initialPassword = "nixos";

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
