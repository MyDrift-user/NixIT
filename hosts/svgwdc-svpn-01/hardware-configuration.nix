# Hardware bits only. Disk layout lives in ./disk.nix (disko).
{ ... }: {
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [
    "ahci" "nvme" "sd_mod" "xhci_pci" "usbhid"
    "virtio_pci" "virtio_blk" "virtio_scsi"
  ];
}
