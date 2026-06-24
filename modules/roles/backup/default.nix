# Backup server (BorgBackup)
# Receives encrypted, deduplicated backups from all hosts
{ config, pkgs, lib, ... }: {

  # BorgBackup repository server
  # Each host gets its own repo under /var/lib/borg/<hostname>
  services.borgbackup.repos = {
    # Define repos per-host — override in host config
    # Example:
    # "mdl-server" = {
    #   path = "/var/lib/borg/mdl-server";
    #   authorizedKeys = [
    #     "ssh-ed25519 AAAA... root@mdl-server"
    #   ];
    # };
  };

  # Ensure backup storage directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/borg 0700 root root -"
  ];

  environment.systemPackages = with pkgs; [
    borgbackup
    borgmatic
  ];

  # SSH for borg transport (uses the existing SSH server)
  # Borg clients connect via: ssh://borg@backup-server/var/lib/borg/<hostname>

  # Optional: dedicated borg user with restricted shell
  users.users.borg = {
    isSystemUser = true;
    group = "borg";
    home = "/var/lib/borg";
    shell = "${pkgs.borgbackup}/bin/borg";
    openssh.authorizedKeys.keys = [
      # Add host SSH public keys here
      # Each key should be prefixed with command restriction:
      # command="borg serve --restrict-to-path /var/lib/borg/<hostname>" ssh-ed25519 AAAA...
    ];
  };
  users.groups.borg = {};
}
