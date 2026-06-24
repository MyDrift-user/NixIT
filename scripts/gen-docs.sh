set -euo pipefail
ROOT=/mnt/c/Users/user/Documents/GitHub
NIXIT="$ROOT/NixIT"; DEP="$ROOT/mdl-infra/deployments"
export SOPS_AGE_KEY_FILE="$DEP/_admin/age-key.txt"
ADMIN_PUB=$(age-keygen -y "$DEP/_admin/age-key.txt")
KUZE_PW="$1"   # plaintext (only the hash is in sops)
cd "$NIXIT"
ext(){ sops -d --extract "[\"$1\"]" "$2" 2>/dev/null; }

# host -> "key@file ..." (file: c=common.yaml a=ad-dc.yaml)
declare -A SVC
SVC[svgmdl-keyc-01]="keycloak/env@c"
SVC[svgmdl-outl-01]="outline/secret-key@c outline/utils-secret@c outline/oidc-client-secret@c"
SVC[svgmdl-pape-01]="paperless/admin-password@c"
SVC[svgmdl-kasm-01]="kasm/admin-password@c"
SVC[svgmdl-head-01]="headscale/oidc-client-secret@c"
SVC[svgmdl-exca-01]="excalidash/env@c"
SVC[svgmdl-mood-01]="moodleng/db-env@c moodleng/app-env@c"
SVC[svgmdl-rumi-01]="rumi/db-env@c rumi/server-env@c"
SVC[svgmdl-fipa-01]="freeipa/env@c"
SVC[svgmdl-sada-01]="ad/admin-password@a ca/intermediate-password@a"
SVC[svgwdc-svpn-01]="fortivpn/config@c"
declare -A NEWT
for h in svgmdl-keyc-01 svgmdl-kasm-01 svgmdl-forg-01 svgmdl-pape-01 svgmdl-outl-01 svgmdl-immi-01 svgmdl-head-01 svgmdl-exca-01 svgmdl-alia-01 svgmdl-game-01; do NEWT[$h]=1; done

HOSTS="desktop mdl-server svgwdc-svpn-01 svgmdl-keyc-01 svgmdl-kasm-01 svgmdl-forg-01 svgmdl-pape-01 svgmdl-outl-01 svgmdl-immi-01 svgmdl-head-01 svgmdl-exca-01 svgmdl-alia-01 svgmdl-game-01 svgmdl-mood-01 svgmdl-rumi-01 svgmdl-fipa-01 svgmdl-sada-01 svgmdl-devl-01"

for h in $HOSTS; do
  AGEPUB=$(ssh-to-age -i "$DEP/$h/ssh_host_ed25519_key.pub")
  {
    echo "# $h — secrets (PLAINTEXT, keep private)"
    echo ""
    echo "- FQDN: $h.doa.lan"
    echo "- age pubkey: \`$AGEPUB\`"
    echo "- SSH host key (seed at install): \`./ssh_host_ed25519_key\`"
    echo ""
    echo "## Admin login (all hosts)"
    echo "- user: \`kuze\`  password: \`$KUZE_PW\`  (also has SSH key + wheel/sudo)"
    if [ -n "${SVC[$h]:-}" ]; then
      echo ""
      echo "## Service secrets"
      for spec in ${SVC[$h]}; do
        key="${spec%@*}"; f="${spec#*@}"; file="secrets/common.yaml"; [ "$f" = a ] && file="secrets/ad-dc.yaml"
        echo "### $key"
        echo '```'
        ext "$key" "$file"
        echo '```'
      done
    fi
    if [ -n "${NEWT[$h]:-}" ]; then
      echo ""
      echo "## Pangolin tunnel (fill from Pangolin)"
      echo '```'; ext "newt/$h" "secrets/common.yaml"; echo '```'
    fi
  } > "$DEP/$h/info.md"
done

# master index + decrypted dumps
{
  echo "# MDL deployments — master secret index (PLAINTEXT)"
  echo ""
  echo "> Generated bootstrap secrets for the NixIT fleet. KEEP PRIVATE. These are"
  echo "> the source of truth; the repo stores only the sops-encrypted copies."
  echo ""
  echo "## Master / admin"
  echo "- admin age pubkey: \`$ADMIN_PUB\`"
  echo "- admin age PRIVATE key: \`_admin/age-key.txt\` (edit secrets: export SOPS_AGE_KEY_FILE to it)"
  echo "- kuze login password (all hosts): \`$KUZE_PW\`"
  echo ""
  echo "## Per-VM files"
  for h in $HOSTS; do echo "- [$h]($h/info.md) — ssh key + age + service secrets"; done
  echo ""
  echo "## Full decrypted common.yaml"
  echo '```yaml'; sops -d secrets/common.yaml; echo '```'
  echo "## Full decrypted ad-dc.yaml"
  echo '```yaml'; sops -d secrets/ad-dc.yaml; echo '```'
} > "$DEP/SECRETS.md"

cat > "$DEP/.gitignore" <<'EOF'
# Never commit these plaintext secrets / private keys anywhere.
*
!.gitignore
EOF

echo "docs written. files per host:"; ls "$DEP/svgmdl-keyc-01/"
echo "master:"; ls -la "$DEP/SECRETS.md"
