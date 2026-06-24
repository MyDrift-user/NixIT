# Server Roles Reference

All server roles are in `modules/roles/`. Each is a self-contained NixOS module that can be composed freely in your flake.nix.

## Role Summary

| Role | Module Path | Ports | Depends On |
|------|------------|-------|------------|
| AD Domain Controller | `modules/roles/ad-dc` | 53, 88, 123, 135, 137-139, 389, 445, 464, 636, 3268-3269, 8443 | — |
| RADIUS | `modules/roles/radius` | 1812-1813/udp | AD DC (for auth) |
| RDP Session Host | `modules/roles/rdp-session-host` | 3389 | — |
| File Server | `modules/roles/file-server` | 139, 445 | AD DC (for domain join) |
| DNS Forwarder | `modules/roles/dns-forwarder` | 53 | AD DC (for domain zone) |
| DHCP Server | `modules/roles/dhcp` | 67-68/udp | — |
| Print Server | `modules/roles/print-server` | 631, 5353/udp | — |
| Backup Server | `modules/roles/backup` | 22 (SSH) | — |

Docker Host is not a separate role — it's part of `modules/server/` and included by default on all servers.

## AD Domain Controller

**File:** `modules/roles/ad-dc/default.nix`

The all-in-one domain controller. Includes:
- Samba AD DC (custom overlay with DC support)
- Samba internal DNS
- Chrony NTP server (Swiss pool, serves LAN clients)
- step-ca internal certificate authority

> **Deployed as a host:** `modules/services/samba-ad/` wraps this role with a
> concrete realm (`AD.DOA.LAN`) and is the `svgmdl-sada-01` VM — see its
> [README](../modules/services/samba-ad/README.md) for the turnkey steps. There's
> also a containerized **FreeIPA** DC (`svgmdl-fipa-01`,
> [README](../modules/services/freeipa/README.md)). The notes below are the raw role.

**Template values to override** (the samba-ad wrapper sets these for you):
- `services.samba.settings.global."realm"` / `"workgroup"` / `"netbios name"`
- `services.samba.settings.global."dns forwarder"`
- `security.krb5.settings.libdefaults.default_realm` — must match realm
- `services.step-ca.settings.dnsNames`

**Post-install:** Run `provision.sh` (creates the domain + Administrator).

**Provisioning script:** `modules/roles/ad-dc/provision.sh`

---

## RADIUS

**File:** `modules/roles/radius/default.nix`

FreeRADIUS for 802.1X (WPA2-Enterprise) authentication against AD/LDAP.

**Post-install setup required:**
1. Copy default FreeRADIUS config to `/etc/raddb`
2. Configure `mods-enabled/ldap` to point at your AD DC (LDAPS on port 636)
3. Configure `mods-enabled/eap` for PEAP/MSCHAPv2
4. Add access points to `clients.conf` with shared secrets
5. Test: `radtest user password localhost 0 testing123`

**Secrets used:**
- `radius/ldap-bind-password` — LDAP bind account password
- `radius/shared-secret` — RADIUS shared secret for APs

---

## RDP Session Host

**File:** `modules/roles/rdp-session-host/default.nix`

Multi-user xrdp server with GNOME desktop sessions. Each user gets an isolated GNOME session via RDP.

**No post-install configuration needed.** Connect with any RDP client to port 3389.

For AD-integrated login, additionally configure PAM to authenticate against your domain.

---

## File Server

**File:** `modules/roles/file-server/default.nix`

AD-integrated SMB file shares with Winbind for user/group resolution.

**Template values to override:**
- `services.samba.settings.global."workgroup"` — your AD NetBIOS name
- `services.samba.settings.global."realm"` — your AD realm
- `security.krb5.settings.libdefaults.default_realm` — must match realm

**Post-install:**
1. Join the domain: `kinit Administrator && adcli join YOURCOMPANY.LAN`
2. Add share definitions in your host config:
   ```nix
   services.samba.settings.myshare = {
     "path" = "/srv/shares/myshare";
     "read only" = "no";
     "valid users" = "@\"YOURCOMPANY\\Domain Users\"";
   };
   ```
3. Create directories and rebuild

---

## DNS Forwarder

**File:** `modules/roles/dns-forwarder/default.nix`

Unbound DNS with split-horizon forwarding. Internal domain queries go to your AD DC, everything else goes upstream.

**Template values to override:**
- `services.unbound.settings.forward-zone` — update domain name and DC IP

---

## DHCP Server

**File:** `modules/roles/dhcp/default.nix`

Kea DHCPv4 with declarative subnet, pool, and reservation configuration.

**Template values to override:**
- `services.kea.dhcp4.settings.interfaces-config.interfaces` — your network interface
- `services.kea.dhcp4.settings.subnet4` — subnet, pools, options, reservations

The default template has a `10.0.1.0/24` subnet. Override entirely in your host config.

---

## Print Server

**File:** `modules/roles/print-server/default.nix`

CUPS print server with:
- Samba printer sharing (Windows clients)
- Avahi/mDNS discovery (Linux/Mac clients)
- Gutenprint + HPLIP drivers

**Post-install:** Add printers via the CUPS web interface at `http://<server>:631`.

---

## Backup Server

**File:** `modules/roles/backup/default.nix`

BorgBackup repository server with a dedicated `borg` user and SSH-based transport.

**Setup:**
1. Add client SSH public keys to `services.borgbackup.repos`:
   ```nix
   services.borgbackup.repos."dc01" = {
     path = "/var/lib/borg/dc01";
     authorizedKeys = [ "ssh-ed25519 AAAA... root@dc01" ];
   };
   ```
2. On clients, configure borgmatic to push to `borg@backup-server:/var/lib/borg/<hostname>`

For append-only (ransomware-resistant) backups, use `authorizedKeysAppendOnly` instead.

## Combining Roles

Roles can be freely combined on a single host. Common patterns:

**Small office (1 server does everything):**
```nix
modules = [
  ./modules/core
  ./modules/server
  ./modules/roles/ad-dc
  ./modules/roles/dhcp
  ./modules/roles/file-server
  ./modules/roles/print-server
  ./hosts/office-server
];
```

**Enterprise (dedicated servers):**
```
dc01:          core + server + ad-dc
dc02:          core + server + ad-dc  (replica)
files:         core + server + file-server
radius:        core + server + radius
print:         core + server + print-server
backup:        core + server + backup
docker:        core + server  (Docker host for web apps)
```

**Conflicts to avoid:**
- Don't combine `ad-dc` and `file-server` on the same host — they both configure `services.samba` differently
- Don't combine `ad-dc` and `dns-forwarder` — the DC runs its own DNS
