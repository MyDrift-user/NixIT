# AD Domain Controller Setup

> **Deployed host:** the Samba AD DC ships as `svgmdl-fipa-01`'s sibling
> `svgmdl-sada-01` (realm `AD.DOA.LAN`) via `modules/services/samba-ad/`, which
> wraps this role — its [README](../modules/services/samba-ad/README.md) has the
> concrete turnkey steps. There's also a containerized **FreeIPA** DC
> (`svgmdl-fipa-01`, [README](../modules/services/freeipa/README.md)). The guide
> below is the generic Samba-AD reference (substitute your realm for `YOURCOMPANY.LAN`).

## Overview

The AD DC role (`modules/roles/ad-dc/`) provides a complete Active Directory domain controller with:

- **Samba AD DC** — Active Directory compatible domain controller
- **Internal DNS** — Samba's built-in DNS server (no BIND needed)
- **NTP Server** — Chrony time server (Kerberos requires accurate time)
- **Internal CA** — step-ca certificate authority for LDAPS, RADIUS EAP, and internal TLS

## Architecture

```
                    ┌─────────────────────────────────┐
                    │        AD Domain Controller      │
                    │                                   │
                    │  Samba AD DC (port 389/636/445)   │
                    │  Internal DNS (port 53)           │
                    │  Kerberos KDC (port 88)           │
                    │  Chrony NTP (port 123)            │
                    │  step-ca (port 8443)              │
                    └─────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
     ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐
     │ File Server  │  │  RADIUS     │  │ Workstations│
     │ (domain      │  │ (EAP auth   │  │ (domain     │
     │  joined)     │  │  via LDAP)  │  │  joined)    │
     └─────────────┘  └─────────────┘  └─────────────┘
```

## Prerequisites

- Static IP address (set during installation or in `network.nix`)
- A chosen domain name (e.g., `YOURCOMPANY.LAN`)
- Hostname under 15 characters (NetBIOS limitation)
- Do NOT use `.local` as TLD (conflicts with mDNS/Avahi)

## Configuration

### Per-Host Overrides

In your host's `default.nix`, override the template values:

```nix
{ lib, ... }: {
  imports = [ ./hardware-configuration.nix ./network.nix ./users.nix ./platform.nix ./boot.nix ];

  # Override AD DC defaults
  services.samba.settings.global = {
    "realm" = lib.mkForce "YOURCOMPANY.LAN";
    "workgroup" = lib.mkForce "YOURCOMPANY";
    "netbios name" = lib.mkForce "DC01";
    "dns forwarder" = lib.mkForce "1.1.1.1";
  };

  # Match Kerberos realm
  security.krb5.settings.libdefaults.default_realm = lib.mkForce "YOURCOMPANY.LAN";

  # Update CA DNS names
  services.step-ca.settings.dnsNames = lib.mkForce [ "ca.yourcompany.lan" "dc01.yourcompany.lan" "localhost" ];

  # Update netlogon path to match lowercase realm
  services.samba.settings.netlogon."path" = lib.mkForce "/var/lib/samba/sysvol/yourcompany.lan/scripts";

  system.stateVersion = "25.11";
}
```

### Network Configuration

The DC must have a static IP. Example `network.nix`:

```nix
{ lib, ... }: {
  networking.hostName = "dc01";
  networking.useDHCP = lib.mkForce false;
  networking.interfaces.eth0 = {
    ipv4.addresses = [{ address = "10.0.1.10"; prefixLength = 24; }];
  };
  networking.defaultGateway.address = "10.0.1.1";
  # DNS points to itself (Samba internal DNS)
  # This is handled by the AD DC module automatically
}
```

## Post-Install: Domain Provisioning

After the first boot, the domain database must be initialized. This is a **one-time** operation:

```bash
sudo bash ~/provision.sh \
  --realm=YOURCOMPANY.LAN \
  --domain=YOURCOMPANY \
  --admin-pass='YourSecureP@ssw0rd!'
```

The admin password must meet complexity requirements (uppercase, lowercase, number, special char, 8+ chars).

### What Provisioning Creates

- `/var/lib/samba/private/sam.ldb` — the AD LDAP database
- `/var/lib/samba/sysvol/` — Group Policy container
- Kerberos keytab files
- Default accounts: `Administrator`, `Guest`, `krbtgt`

## Post-Install: Initialize the CA

The internal CA needs one-time initialization:

```bash
# Initialize the CA (interactive)
sudo -u step-ca step ca init \
  --name="YOURCOMPANY Internal CA" \
  --dns="ca.yourcompany.lan,dc01.yourcompany.lan,localhost" \
  --address=":8443" \
  --provisioner="admin"

# Restart step-ca to pick up the new config
sudo systemctl restart step-ca
```

### Issue a Certificate

```bash
# Get a cert for a service
step ca certificate "ldaps.yourcompany.lan" server.crt server.key

# Install it for Samba LDAPS
sudo cp server.crt /var/lib/samba/private/tls/cert.pem
sudo cp server.key /var/lib/samba/private/tls/key.pem
sudo systemctl restart samba-dc
```

## Verification

```bash
# Samba AD DC
samba-tool user list
samba-tool domain info 127.0.0.1

# Kerberos
kinit Administrator
klist

# DNS
dig @localhost yourcompany.lan
dig @localhost _ldap._tcp.yourcompany.lan SRV
dig @localhost _kerberos._tcp.yourcompany.lan SRV

# NTP
chronyc tracking
chronyc clients         # See which machines are syncing

# CA
step ca health
step ca root            # Show root CA certificate
```

## Joining Clients to the Domain

### Windows Client

1. Set the client's DNS to point at the DC (e.g., `10.0.1.10`)
2. System > About > Domain or Workgroup > Change > Domain: `YOURCOMPANY`
3. Enter `Administrator` credentials when prompted
4. Reboot

### NixOS Client (File Server, etc.)

```bash
# Set DNS to the DC
# Install krb5 and adcli
kinit Administrator@YOURCOMPANY.LAN
sudo adcli join YOURCOMPANY.LAN
```

## Firewall Ports

| Port | Protocol | Service |
|------|----------|---------|
| 53 | TCP/UDP | DNS |
| 88 | TCP/UDP | Kerberos |
| 123 | UDP | NTP |
| 135 | TCP | MSRPC |
| 137-138 | UDP | NetBIOS |
| 139 | TCP | NetBIOS Session |
| 389 | TCP/UDP | LDAP |
| 445 | TCP | SMB |
| 464 | TCP/UDP | Kerberos kpasswd |
| 636 | TCP | LDAPS |
| 3268-3269 | TCP | Global Catalog |
| 8443 | TCP | step-ca |

## Backup

Critical data to back up:

- `/var/lib/samba/` — entire Samba database, sysvol, TLS certs
- `/var/lib/step-ca/` — CA certificates and keys
- `/etc/nixos/` — system configuration

Use `samba-tool domain backup` for online AD backups.

## Adding a Second DC

To add a replica DC, provision a second server with the AD DC role but instead of running `provision.sh`, join it to the existing domain:

```bash
samba-tool domain join YOURCOMPANY.LAN DC \
  --dns-backend=SAMBA_INTERNAL \
  --option="dns forwarder = 10.0.1.10"
```
