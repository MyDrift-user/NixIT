# Samba Active Directory domain controller — wraps modules/roles/ad-dc with this
# host's realm/domain. The role provides Samba AD DC + Kerberos + internal DNS +
# Chrony NTP + step-ca. Realm AD.DOA.LAN.
#
# Provision ONCE after first boot (creates the domain + Administrator):
#   sudo bash $(nix eval --raw .#...)/provision.sh  — or copy modules/roles/ad-dc/
#   provision.sh and run: sudo bash provision.sh --realm=AD.DOA.LAN --domain=AD \
#     --admin-pass=<pw>
# See README for example users, root/admin rights, and OIDC notes.
{ lib, ... }: {
  imports = [ ../../roles/ad-dc ];

  services.samba.settings.global = {
    "realm"        = lib.mkForce "AD.DOA.LAN";
    "workgroup"    = lib.mkForce "AD";
    "netbios name" = lib.mkForce "SADA01";
    "dns forwarder" = lib.mkForce "1.1.1.1";
  };
  services.samba.settings.netlogon."path" =
    lib.mkForce "/var/lib/samba/sysvol/ad.doa.lan/scripts";

  security.krb5.settings.libdefaults.default_realm = lib.mkForce "AD.DOA.LAN";
  services.step-ca.settings.dnsNames = lib.mkForce [ "ca.ad.doa.lan" "localhost" ];
}
