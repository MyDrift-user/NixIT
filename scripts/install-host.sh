#!/usr/bin/env bash
# Remote install via disko + nixos-anywhere, with sops bootstrap.
#
#   ./scripts/install-host.sh <flake-host> <user@target-ip>
#   ./scripts/install-host.sh mdl-server  root@192.168.1.50
#
# The target just needs to be booted into ANY Linux you can SSH into (the NixOS
# minimal ISO, this repo's ISO, or nixos-anywhere's built-in kexec image).
# disko partitions per hosts/<host>/disk.nix, then NixOS is installed.
#
# WARNING: the target's disk is WIPED. Never point this at a machine with data
# you care about.
set -euo pipefail

HOST="${1:?usage: install-host.sh <flake-host> <user@target>}"
TARGET="${2:?usage: install-host.sh <flake-host> <user@target>}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
install -d -m700 "$tmp/etc/ssh"

# Seed the host's SSH key so its sops age identity matches .sops.yaml and first
# boot can decrypt. Prefer the pre-generated key from the deployments folder
# (created by scripts/gen-secrets.sh); otherwise generate a fresh one and remind
# you to register it.
PREGEN="$(dirname "$0")/../../mdl-infra/deployments/$HOST/ssh_host_ed25519_key"
if [ -f "$PREGEN" ]; then
  echo "==> Seeding pre-generated host key from mdl-infra/deployments/$HOST"
  install -m600 "$PREGEN"     "$tmp/etc/ssh/ssh_host_ed25519_key"
  install -m644 "$PREGEN.pub" "$tmp/etc/ssh/ssh_host_ed25519_key.pub"
else
  echo "==> No pre-generated key found; generating a fresh one."
  ssh-keygen -t ed25519 -f "$tmp/etc/ssh/ssh_host_ed25519_key" -N "" -C "root@$HOST"
  echo "==> Add this age pubkey to .sops.yaml as &$HOST, then \`sops updatekeys secrets/*.yaml\`:"
  nix run nixpkgs#ssh-to-age -- -i "$tmp/etc/ssh/ssh_host_ed25519_key.pub"
  read -rp "Done? press enter to continue… "
fi

nix run github:nix-community/nixos-anywhere -- \
  --flake ".#$HOST" \
  --extra-files "$tmp" \
  "$TARGET"

echo "==> Done. Future updates:  nix run github:serokell/deploy-rs -- .#$HOST"
