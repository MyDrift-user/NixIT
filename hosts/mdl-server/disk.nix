# Declarative disk layout (disko).
#
# nixos-anywhere uses this to partition + format the target at install time.
# On an ALREADY-running system importing this only *declares* fileSystems/swap
# — it never reformats. Reformatting happens only via `nixos-anywhere` or an
# explicit `disko` run.
#
# Set `device` to the install target (check with `lsblk`). UEFI + GPT + btrfs
# subvolumes (@, @home, @nix, @log) with zstd compression, matching the rest
# of the fleet.
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
