#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: run this on the Proxmox host as root."
  exit 1
fi

command -v pveum >/dev/null || {
  echo "ERROR: pveum not found. Run this on the Proxmox host."
  exit 1
}

USERID="prometheus@pve"
TOKENID="r515-monitoring"
FULLTOKEN="${USERID}!${TOKENID}"

echo "=== R515 PROXMOX READ-ONLY MONITORING TOKEN ==="

echo
echo "[1] Ensuring dedicated monitoring user exists"
if pveum user list --output-format json 2>/dev/null | grep -q '"userid":"prometheus@pve"'; then
  echo "INFO: ${USERID} already exists."
else
  pveum user add "$USERID" --comment "Read-only R515 Prometheus monitoring"
  echo "PASS: created ${USERID}."
fi

echo
echo "[2] Giving backing user read-only PVEAuditor access at /"
pveum acl modify / -user "$USERID" -role PVEAuditor
echo "PASS: backing user is read-only."

echo
echo "[3] Checking monitoring token"
if pveum user token list "$USERID" --output-format json 2>/dev/null | grep -q '"tokenid":"r515-monitoring"'; then
  echo "ERROR: ${FULLTOKEN} already exists."
  echo "The token secret is only shown when a token is created, so this script will not replace it automatically."
  echo "If you no longer have the secret, remove/recreate the token intentionally before continuing."
  exit 1
fi

echo
echo "[4] Creating privilege-separated token"
echo "IMPORTANT: copy the token VALUE shown below. It is displayed only once."
echo "Do not paste that value into ChatGPT or GitHub."
echo
pveum user token add "$USERID" "$TOKENID" -privsep 1

echo
echo "[5] Giving the token its own read-only PVEAuditor access at /"
pveum acl modify / -token "$FULLTOKEN" -role PVEAuditor
echo "PASS: token is limited to PVEAuditor."

echo
echo "[6] Verifying effective token permissions"
pveum user token permissions "$USERID" "$TOKENID"

echo
echo "=== PROXMOX TOKEN SETUP COMPLETE ==="
echo "User:       ${USERID}"
echo "Token name: ${TOKENID}"
echo "Role:       PVEAuditor"
echo "Scope:      /"
echo "Privsep:    enabled"
echo
echo "Next: use the one-time token VALUE on docker01 when installing prometheus-pve-exporter."
