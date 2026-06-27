# Kasm Workspaces — host fully prepared, install is one command.
#
# Kasm is a multi-container platform that bootstraps its own DB/certs/admin via
# an installer (no native module, no clean oci-containers path). So this host is
# a hardened Docker host with everything staged — storage, ports, the admin
# password (sops), and a `kasm-install` command — so the manual step is trivial:
#
#   sudo kasm-install <release-url-from-kasmweb.com/downloads>
#
# (or set nixit.kasm.releaseUrl and just `sudo kasm-install`). Then configure
# OIDC + shares + the default desktop in the admin UI — see the MOTD / below.
{ config, lib, pkgs, ... }:
let
  adminPw = config.sops.secrets."kasm/admin-password".path;
  kasm-install = pkgs.writeShellScriptBin "kasm-install" ''
    set -euo pipefail
    [ "$(id -u)" -eq 0 ] || { echo "run as root: sudo kasm-install [release-url]"; exit 1; }
    url="$1"; [ -n "$url" ] || url="${config.nixit.kasm.releaseUrl}"
    [ -n "$url" ] || { echo "usage: sudo kasm-install <release-tarball-url>  (https://www.kasmweb.com/downloads)"; exit 1; }
    cd /opt/kasm
    if [ ! -d kasm_release ]; then
      ${pkgs.curl}/bin/curl -fSL -o kasm_release.tar.gz "$url"
      ${pkgs.gnutar}/bin/tar -xf kasm_release.tar.gz
    fi
    bash kasm_release/install.sh --accept-eula --swap-size 4096 \
      --admin-password "$(cat ${adminPw})" \
      --user-password  "$(cat ${adminPw})"
    echo "Kasm installed. Admin UI: https://office.lua.li (or https://<this-host>)."
  '';
in {
  options.nixit.kasm.releaseUrl = lib.mkOption {
    type = lib.types.str;
    default = "";
    example = "https://kasm-static-content.s3.amazonaws.com/kasm_release_1.17.0.7f020d.tar.gz";
    description = "Default Kasm release tarball URL (the file name carries a build hash; copy it from kasmweb.com/downloads).";
  };

  config = {
    networking.firewall.allowedTCPPorts = [ 443 8443 ];
    systemd.tmpfiles.rules = [ "d /opt/kasm 0750 root root -" ];
    sops.secrets."kasm/admin-password".sopsFile = ../../../secrets/common.yaml;

    environment.systemPackages = [ kasm-install pkgs.curl pkgs.gnutar pkgs.lsof pkgs.procps pkgs.which pkgs.iproute2 pkgs.gawk pkgs.gnused ];

    users.motd = ''
      Kasm host — prepared, not yet installed.
        1) sudo kasm-install <release-url from https://www.kasmweb.com/downloads>
           admin + user passwords are taken from sops (kasm/admin-password)
        2) Admin UI (proxied at https://office.lua.li):
           - OIDC: Issuer https://mdl.auth.li/realms/main, client "kasm" (id + secret)
                   map a Keycloak group/role -> a Kasm group for auto-provisioning
           - Groups > Settings: default Workspace (login lands in it) + Volume
             Mappings for network shares (//fileserver/share -> /home/kasm-user/share)
    '';
  };
}
