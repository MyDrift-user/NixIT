# Proxmox/KVM guest configuration
# Imported by modules/server/default.nix — applies to all servers
{ ... }: {
  services.qemuGuest.enable = true;

  # VirtIO drivers in initrd for reliable boot
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
    "virtio_balloon"
    "virtio_rng"
    "9p"
    "9pnet_virtio"
  ];

  boot.kernelModules = [
    "virtio_balloon"
    "virtio_rng"
  ];

  # Serial console for Proxmox noVNC/xterm.js
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
  ];

  # Trim for thin-provisioned Proxmox storage
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # VirtIO disks: let the host handle I/O scheduling
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="vd[a-z]*", ATTR{queue/scheduler}="none"
    ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
  '';
}
