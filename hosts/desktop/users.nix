# Desktop users
{ config, pkgs, ... }: {
  # Password from sops, per-host key kuze/password/<hostname>.
  sops.secrets."kuze/password/${config.networking.hostName}" = {
    sopsFile = ../../secrets/common.yaml;
    neededForUsers = true;
  };

  users.users.kuze = {
    isNormalUser  = true;
    description   = "kuze";
    extraGroups   = [ "networkmanager" "wheel" "docker" "video" "audio" "input" ];
    shell         = pkgs.bash;
    hashedPasswordFile = config.sops.secrets."kuze/password/${config.networking.hostName}".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINStVTxixre56N5GRSBCIAQTQYQMbFPfrLsCe2l0rUHe"
    ];
  };
}
