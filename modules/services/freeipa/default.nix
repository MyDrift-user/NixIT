# FreeIPA — identity management domain controller (LDAP + Kerberos + CA).
#
# FreeIPA has no usable native NixOS packaging; upstream ships it as a
# systemd-in-container appliance, so we run the official image. It installs
# unattended on first boot from the cmd args + PASSWORD, then just starts on
# later boots (it detects an existing /data). Host networking because FreeIPA
# binds many ports; the systemd-in-docker bits (cgroup mount, tmpfs) are the
# known-fragile part — see README if first install needs flag tuning.
#
# Realm/domain default to IPA.DOA.LAN / ipa.doa.lan — EDIT below to taste.
# OIDC: FreeIPA federates to an external IdP via `ipa idp-add` (Keycloak/Entra/
# Google) — see README; nothing to wire declaratively.
#
# Secret (sops secrets/common.yaml, key `freeipa/env`):
#   PASSWORD=<admin + Directory Manager password, >=8 chars>
{ config, ... }:
let
  fqdn  = "ipa.doa.lan";
  realm = "IPA.DOA.LAN";
in {
  sops.secrets."freeipa/env".sopsFile = ../../../secrets/common.yaml;

  virtualisation.oci-containers.containers.freeipa = {
    image = "freeipa/freeipa-server:almalinux-10";   # pin a digest in production
    # Unattended install (ignored once /data is populated). Add --setup-dns
    # --auto-forwarders to run FreeIPA's integrated DNS (then also open 53 below).
    cmd = [ "ipa-server-install" "-U" "-r" realm "--domain" "doa.lan" "--no-ntp" "--no-host-dns" ];
    environment.IPA_SERVER_HOSTNAME = fqdn;
    environmentFiles = [ config.sops.secrets."freeipa/env".path ];
    volumes = [
      "/srv/freeipa/data:/data:Z"
      "/sys/fs/cgroup:/sys/fs/cgroup:ro"
    ];
    extraOptions = [
      "--network=host"
      "--sysctl=net.ipv6.conf.all.disable_ipv6=0"
      "--cgroupns=host"
      "--security-opt=seccomp=unconfined"
      "--tmpfs=/run"
      "--tmpfs=/tmp"
    ];
  };

  systemd.tmpfiles.rules = [ "d /srv/freeipa 0750 root root -" "d /srv/freeipa/data 0750 root root -" ];

  # IdM ports (LDAP/LDAPS, Kerberos, HTTP/HTTPS). Add 53 tcp/udp if you enable
  # integrated DNS (--setup-dns above).
  networking.firewall.allowedTCPPorts = [ 80 443 88 464 389 636 ];
  networking.firewall.allowedUDPPorts = [ 88 464 ];
}
