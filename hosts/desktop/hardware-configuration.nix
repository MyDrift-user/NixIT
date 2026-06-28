# Hardware bits only. Disk layout (fileSystems + swap) lives in ./disk.nix (disko).
# Regenerate the hardware parts (NOT filesystems) on real hardware with:
#   nixos-generate-config --no-filesystems --show-hardware-config
{ ... }: {
  boot.loader.systemd-boot.enable      = true;
  # false: installed via nixos-anywhere; its kexec installer inherits the SeaBIOS
  # firmware mode (no efivarfs), so writing EFI NVRAM vars would fail. systemd-boot
  # still installs the removable fallback (\EFI\BOOT\BOOTX64.EFI), so after the VM
  # is converted to OVMF it boots via that path without an NVRAM entry.
  boot.loader.efi.canTouchEfiVariables = false;

  boot.initrd.availableKernelModules = [
    "ahci" "nvme" "sd_mod" "xhci_pci" "usbhid"
    "virtio_pci" "virtio_blk" "virtio_scsi"
  ];
}
