# MDL server network configuration
# For static IP, replace useDHCP with the commented block below
{ ... }: {
  networking.hostName = "mdl-server";
  networking.useDHCP  = true;

  # Static IP example:
  # networking.useDHCP = lib.mkForce false;
  # networking.interfaces.eth0 = {
  #   ipv4.addresses = [{ address = "10.0.1.10"; prefixLength = 24; }];
  # };
  # networking.defaultGateway.address = "10.0.1.1";
  # networking.nameservers = [ "10.0.1.1" "1.1.1.1" ];
}
