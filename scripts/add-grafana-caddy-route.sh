#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: run this script as root."
  echo "Use: sudo bash $0"
  exit 1
fi

CADDYFILE="/srv/docker/caddy/Caddyfile"
CADDY_CONTAINER="caddy"
DOMAIN="grafana.r515.allenfamhouse.com"
UPSTREAM="192.168.10.135:3003"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${CADDYFILE}.pre-grafana-${STAMP}"
CANDIDATE="/tmp/Caddyfile.grafana.${STAMP}"
CONTAINER_CANDIDATE="/tmp/Caddyfile.grafana.candidate"

cleanup() {
  rm -f "$CANDIDATE"
  docker exec "$CADDY_CONTAINER" rm -f "$CONTAINER_CANDIDATE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=== ADD GRAFANA PRIVATE CADDY ROUTE ==="

[ -f "$CADDYFILE" ] || { echo "ERROR: $CADDYFILE not found."; exit 1; }

if grep -Fq "$DOMAIN" "$CADDYFILE"; then
  echo "Route already exists."
  exit 0
fi

echo
echo "[1] Checking Grafana"
curl -fsS --max-time 5 "http://${UPSTREAM}/api/health" >/dev/null
echo "PASS"

echo
echo "[2] Creating backup/candidate"
cp -a "$CADDYFILE" "$BACKUP"
cp "$CADDYFILE" "$CANDIDATE"

cat >> "$CANDIDATE" <<EOF

${DOMAIN} {
    import private_only
    tls internal
    reverse_proxy ${UPSTREAM}
}
EOF

echo "Backup: $BACKUP"

echo
echo "[3] Validating candidate"
docker cp "$CANDIDATE" "${CADDY_CONTAINER}:${CONTAINER_CANDIDATE}"
docker exec "$CADDY_CONTAINER" caddy validate --config "$CONTAINER_CANDIDATE" --adapter caddyfile
echo "PASS"

echo
echo "[4] Applying in-place"
cat "$CANDIDATE" | tee "$CADDYFILE" >/dev/null

echo
echo "[5] Checking bind mount"
HOST_HASH="$(sha256sum "$CADDYFILE" | awk '{print $1}')"
CONTAINER_HASH="$(docker exec "$CADDY_CONTAINER" sha256sum /etc/caddy/Caddyfile | awk '{print $1}')"

echo "host:      $HOST_HASH"
echo "container: $CONTAINER_HASH"

if [ "$HOST_HASH" != "$CONTAINER_HASH" ]; then
  echo "ERROR: stale Caddy bind mount detected."
  exit 1
fi

echo "PASS"

echo
echo "[6] Reloading Caddy"
docker kill --signal=USR1 "$CADDY_CONTAINER" >/dev/null
sleep 2

echo
echo "[7] Testing clean URL"
HTTP_CODE="$(curl -k -sS -o /dev/null -w '%{http_code}' --resolve "${DOMAIN}:443:127.0.0.1" "https://${DOMAIN}/api/health" || true)"
echo "HTTP $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
  echo "PASS: https://${DOMAIN}"
else
  echo "FAIL: clean route did not return 200."
  exit 1
fi

echo
echo "=== COMPLETE ==="
