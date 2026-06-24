#!/usr/bin/env bash
# Build the NixIT installer ISO
# Output: result/iso/nixit-installer.iso
set -euo pipefail

case "${1:-iso}" in
  iso)
    echo "Building NixIT installer ISO..."
    nix build .#nixosConfigurations.iso.config.system.build.isoImage -L
    echo ""
    echo "Done! ISO is at:"
    ls -lh result/iso/*.iso
    ;;
  proxmox)
    echo "Building NixIT Proxmox VM image..."
    nix build .#proxmox-image -L
    echo ""
    echo "Done! Image is at:"
    ls -lh result/
    echo ""
    echo "Import into Proxmox:"
    echo "  qmrestore ./result/*.vma.zst <vmid> --unique true"
    ;;
  *)
    echo "Usage: $0 [iso|proxmox]"
    echo "  iso      Build bootable installer ISO (default)"
    echo "  proxmox  Build Proxmox VM image (.vma.zst)"
    exit 1
    ;;
esac
