#!/usr/bin/env bash
# Samba AD DC domain provisioning — run ONCE after first boot
# Usage: sudo bash provision.sh --realm=MYDOMAIN.LAN --domain=MYDOMAIN --admin-pass=<password>
set -euo pipefail

REALM=""
DOMAIN=""
ADMIN_PASS=""
DNS_FORWARDER="1.1.1.1"

for arg in "$@"; do
  case "$arg" in
    --realm=*)       REALM="${arg#*=}" ;;
    --domain=*)      DOMAIN="${arg#*=}" ;;
    --admin-pass=*)  ADMIN_PASS="${arg#*=}" ;;
    --dns-forwarder=*) DNS_FORWARDER="${arg#*=}" ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

if [ -z "$REALM" ] || [ -z "$DOMAIN" ] || [ -z "$ADMIN_PASS" ]; then
  echo "Usage: sudo bash provision.sh --realm=MYDOMAIN.LAN --domain=MYDOMAIN --admin-pass=<password>"
  echo "  Optional: --dns-forwarder=1.1.1.1"
  exit 1
fi

[ "$EUID" -ne 0 ] && { echo "ERROR: Run as root"; exit 1; }

echo "Provisioning Samba AD DC..."
echo "  Realm:    $REALM"
echo "  Domain:   $DOMAIN"
echo "  DNS:      $DNS_FORWARDER"
echo ""

# Stop Samba before provisioning
systemctl stop samba 2>/dev/null || true

samba-tool domain provision \
  --server-role=dc \
  --use-rfc2307 \
  --dns-backend=SAMBA_INTERNAL \
  --realm="$REALM" \
  --domain="$DOMAIN" \
  --adminpass="$ADMIN_PASS"

# Copy Kerberos config
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf 2>/dev/null || true

# Start Samba
systemctl start samba

echo ""
echo "Domain provisioned successfully!"
echo "  Test: samba-tool user list"
echo "  Test: kinit Administrator"
echo ""
echo "Next steps:"
echo "  1. Update hosts/<hostname>/default.nix with actual realm/domain values"
echo "  2. Run: nixos-rebuild switch --flake /etc/nixos"
