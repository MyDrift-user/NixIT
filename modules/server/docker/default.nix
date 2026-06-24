# Docker configuration - all servers
{ ... }: {

  virtualisation.docker = {
    enable       = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates  = "daily";
      flags  = [ "--all" ];
    };
    daemon.settings = {
      live-restore = true;
      default-address-pools = [
        { base = "172.17.0.0/16"; size = 27; }
        { base = "192.168.0.0/16"; size = 27; }
      ];
    };
  };

  virtualisation.oci-containers.backend = "docker";

  systemd.services.docker.serviceConfig = {
    Restart          = "always";
    RestartMaxDelaySec = "5min";
  };
}
