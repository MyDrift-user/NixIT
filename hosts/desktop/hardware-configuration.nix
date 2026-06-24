# Hardware bits only. Disk layout (fileSystems + swap) lives in ./disk.nix (disko).
# Regenerate the hardware parts (NOT filesystems) on real hardware with:
#   nixos-generate-config --no-filesystems --show-hardware-config
{ ... }: {
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [
    "ahci" "nvme" "sd_mod" "xhci_pci" "usbhid"
    "virtio_pci" "virtio_blk" "virtio_scsi"
  ];
}
