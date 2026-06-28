# Hardware bits only. Disk layout (fileSystems + swap) lives in ./disk.nix (disko).
# Regenerate the hardware parts on real hardware with:
#   nixos-generate-config --no-filesystems --show-hardware-config
{ ... }: {
  boot.loader.systemd-boot.enable      = true;
  # false: this VM is installed via nixos-anywhere whose kexec installer inherits
  # the boot firmware mode. The box ships as SeaBIOS, so the installer has no
  # efivarfs — writing EFI NVRAM vars would fail. systemd-boot still installs the
  # removable fallback (\EFI\BOOT\BOOTX64.EFI), so after converting the VM to OVMF
  # it boots via that path without needing an NVRAM entry.
  boot.loader.efi.canTouchEfiVariables = false;

  boot.initrd.availableKernelModules = [
    "ahci" "nvme" "sd_mod" "xhci_pci" "usbhid"
    "virtio_pci" "virtio_blk" "virtio_scsi"
  ];
}
