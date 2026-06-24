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
  system.stateVersion = "25.11";
}
