# MDL server users
{ config, ... }: {
  # Password comes from sops, not git (per-host key kuze/password/<hostname>, so
  # each machine has its own). SSH key login works regardless.
  sops.secrets."kuze/password/${config.networking.hostName}" = {
    sopsFile = ../../secrets/common.yaml;
    neededForUsers = true;
  };

  users.users.kuze = {
    isNormalUser  = true;
    uid           = 1010;
    description   = "kuze";
    extraGroups   = [ "networkmanager" "wheel" "docker" ];
    hashedPasswordFile = config.sops.secrets."kuze/password/${config.networking.hostName}".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINStVTxixre56N5GRSBCIAQTQYQMbFPfrLsCe2l0rUHe"
    ];
  };
}
