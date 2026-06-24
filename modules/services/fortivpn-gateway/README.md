# svgwdc-svpn-01 — FortiGate VPN client (father's network)

A small VM that holds a FortiGate SSL-VPN tunnel using the open client. It only
brings up and keeps the VPN connection; routing it to your users (headscale
subnet router etc.) is done separately by you. (`wdc` is just this VM's name —
not a separate cluster; it lives in this repo.)

## The "8-hour limit"
It's the FortiGate's **server-side `auth-timeout`** (default 28800s), not the
client. openfortivpn has **no license and no client time-limit**, and runs with
`Restart=always`, so it re-authenticates automatically across the timeout →
effectively non-stop (brief blip every ~8h). Free FortiClient can't do that
(no auto-reconnect without an EMS license). If the FortiGate sets `auth-timeout 0`
it's truly uninterrupted. Seamless reconnect needs username/password auth
(MFA/SAML would interrupt it).

## Deploy
1. Secret `fortivpn/config` in `sops secrets/common.yaml` — the openfortivpn
   config (host/port/username/password + `trusted-cert`). Run
   `openfortivpn host:port` once to print the cert sha256 for `trusted-cert`.
2. `./scripts/install-host.sh svgwdc-svpn-01 root@<ip>` → `deploy .#svgwdc-svpn-01`.

## Verify
- `journalctl -u openfortivpn -f` — connection status / reconnects.
- `ip addr show ppp0` — the tunnel interface once connected.
