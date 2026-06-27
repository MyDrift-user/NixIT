# svgwdc-svpn-01 — FortiGate VPN gateway for father's network (single VM, not a
# cluster; lives in this repo, joins the existing headscale).
{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ../mdl-server/users.nix                       # reuse the kuze admin (sops pw + SSH key)
    ../../modules/services/fortivpn-gateway
  ];

  networking.hostName = "svgwdc-svpn-01";
  # Static IP on the WDC VLAN (110, 10.20.10.x) — server VLANs have no DHCP.
  networking.useDHCP = false;
  networking.usePredictableInterfaceNames = false;
  networking.interfaces.eth0.ipv4.addresses = [{ address = "10.20.10.2"; prefixLength = 24; }];
  networking.defaultGateway = "10.20.10.1";
  networking.nameservers = [ "1.1.1.1" "9.9.9.9" ];
  system.stateVersion = "25.11";
}
