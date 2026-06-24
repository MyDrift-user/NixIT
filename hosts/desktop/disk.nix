# Declarative disk layout (disko) — see hosts/mdl-server/disk.nix for notes.
# Set `device` to the install target (`lsblk`); /dev/nvme0n1 is common on laptops.
{ ... }: {
  disko.devices.disk.main = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 10;
          type = "EF00";
          size = "512M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        swap = {
          priority = 20;
          size = "8G";
          content.type = "swap";
        };
        root = {
          priority = 30;
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-L" "nixos" "-f" ];
            subvolumes = {
              "@"     = { mountpoint = "/";        mountOptions = [ "compress=zstd:1" "noatime" ]; };
              "@home" = { mountpoint = "/home";    mountOptions = [ "compress=zstd:1" "noatime" ]; };
              "@nix"  = { mountpoint = "/nix";     mountOptions = [ "compress=zstd:1" "noatime" ]; };
              "@log"  = { mountpoint = "/var/log"; mountOptions = [ "compress=zstd:1" "noatime" ]; };
            };
          };
        };
      };
    };
  };
}
