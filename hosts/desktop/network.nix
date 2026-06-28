# Desktop network configuration
{ ... }: {
  networking.hostName = "desktop";
  # static IP (no DHCP on server VLAN); NM leaves eth0 to scripted networking
  networking.useDHCP = false;
  networking.usePredictableInterfaceNames = false;
  networking.interfaces.eth0.ipv4.addresses = [{ address = "10.10.20.41"; prefixLength = 24; }];
  networking.defaultGateway = "10.10.20.1";
  networking.nameservers = [ "1.1.1.1" "9.9.9.9" ];
  networking.networkmanager.unmanaged = [ "eth0" ];
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO/pHI10e6RYA3gOw8ptXqvdDyJzkE5eL9ZsCMRVUhv+ mdl-deploy"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFXXSk/BLQQ2E3Q7T9WT5/u91MKELNTFpVvMMh1qJFsG user@DESKTOP-FS4MHQ1"
  ];
}
