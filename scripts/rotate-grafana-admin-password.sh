#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: run this script as root."
  echo "Use: sudo bash $0"
  exit 1
fi

BASE_DIR="/srv/docker/monitoring/grafana"
ENV_FILE="${BASE_DIR}/.env"
CONTAINER="grafana"

command -v openssl >/dev/null || { echo "ERROR: openssl missing"; exit 1; }
docker inspect "$CONTAINER" >/dev/null 2>&1 || { echo "ERROR: Grafana container not found."; exit 1; }

NEW_PASSWORD="$(openssl rand -hex 24)"

# Grafana stores the active admin password in its database after first boot,
# so reset it with the Grafana CLI rather than only changing the environment.
docker exec "$CONTAINER" \
  grafana cli --homepath /usr/share/grafana \
  admin reset-admin-password "$NEW_PASSWORD" >/dev/null

if [ -f "$ENV_FILE" ]; then
  TMP="$(mktemp)"
  trap 'rm -f "$TMP"' EXIT

  awk -v pw="$NEW_PASSWORD" '
    BEGIN { changed=0 }
    /^GF_SECURITY_ADMIN_PASSWORD=/ {
      print "GF_SECURITY_ADMIN_PASSWORD=" pw
      changed=1
      next
    }
    { print }
    END {
      if (!changed) print "GF_SECURITY_ADMIN_PASSWORD=" pw
    }
  ' "$ENV_FILE" > "$TMP"

  cat "$TMP" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
else
  umask 077
  cat > "$ENV_FILE" <<EOF
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=${NEW_PASSWORD}
EOF
fi

unset NEW_PASSWORD

echo "Grafana admin password reset successfully."
echo "Username: admin"
echo "Password saved locally in: ${ENV_FILE}"
echo "To view it manually: grep '^GF_SECURITY_ADMIN_PASSWORD=' '${ENV_FILE}'"
echo "The password is intentionally not printed by this script."
