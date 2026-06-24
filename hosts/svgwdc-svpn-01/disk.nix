# Declarative disk layout (disko) — small VM. See hosts/mdl-server/disk.nix for notes.
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
          size = "2G";
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
              "@nix"  = { mountpoint = "/nix";     mountOptions = [ "compress=zstd:1" "noatime" ]; };
              "@log"  = { mountpoint = "/var/log"; mountOptions = [ "compress=zstd:1" "noatime" ]; };
            };
          };
        };
      };
    };
  };
}
