#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: run this script as root."
  echo "Use: sudo bash $0"
  exit 1
fi

CADDYFILE="/srv/docker/caddy/Caddyfile"
CADDY_CONTAINER="caddy"
DOMAIN="scrutiny.r515.allenfamhouse.com"
UPSTREAM="192.168.10.135:8082"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${CADDYFILE}.pre-scrutiny-${STAMP}"
CANDIDATE="/tmp/Caddyfile.scrutiny.${STAMP}"
CONTAINER_CANDIDATE="/tmp/Caddyfile.scrutiny.candidate"

cleanup() {
  rm -f "$CANDIDATE"
  docker exec "$CADDY_CONTAINER" rm -f "$CONTAINER_CANDIDATE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=== ADD SCRUTINY PRIVATE CADDY ROUTE ==="

[ -f "$CADDYFILE" ] || {
  echo "ERROR: $CADDYFILE not found."
  exit 1
}

docker inspect "$CADDY_CONTAINER" >/dev/null 2>&1 || {
  echo "ERROR: Caddy container '$CADDY_CONTAINER' not found."
  exit 1
}

if grep -Fq "$DOMAIN" "$CADDYFILE"; then
  echo "Route for $DOMAIN already exists; no change made."
  exit 0
fi

echo
 echo "[1] Verifying Scrutiny direct endpoint"
curl -fsS --max-time 5 "http://${UPSTREAM}/api/health" >/dev/null
echo "PASS: Scrutiny direct endpoint healthy."

echo
 echo "[2] Creating backup and candidate"
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
 echo "[3] Validating candidate with running Caddy version"
docker cp "$CANDIDATE" "${CADDY_CONTAINER}:${CONTAINER_CANDIDATE}"
docker exec "$CADDY_CONTAINER" \
  caddy validate --config "$CONTAINER_CANDIDATE" --adapter caddyfile

echo "PASS: candidate Caddyfile valid."

echo
 echo "[4] Applying in-place"
# Important: tee truncates/writes the existing file without replacing its inode.
# This preserves the live single-file bind mount used by the Caddy container.
cat "$CANDIDATE" | tee "$CADDYFILE" >/dev/null

echo
 echo "[5] Confirming host/container Caddyfile hashes"
HOST_HASH="$(sha256sum "$CADDYFILE" | awk '{print $1}')"
CONTAINER_HASH="$(docker exec "$CADDY_CONTAINER" sha256sum /etc/caddy/Caddyfile | awk '{print $1}')"

echo "host:      $HOST_HASH"
echo "container: $CONTAINER_HASH"

if [ "$HOST_HASH" != "$CONTAINER_HASH" ]; then
  echo "ERROR: Caddy bind mount is stale; hashes differ."
  echo "The live file was backed up at: $BACKUP"
  exit 1
fi

echo "PASS: bind mount is current."

echo
 echo "[6] Reloading Caddy with SIGUSR1"
docker kill --signal=USR1 "$CADDY_CONTAINER" >/dev/null
sleep 2

echo
 echo "[7] Testing clean private route"
HTTP_CODE="$(curl -k -sS -o /tmp/scrutiny-caddy-test.$$ -w '%{http_code}' \
  --resolve "${DOMAIN}:443:127.0.0.1" \
  "https://${DOMAIN}/api/health" || true)"
rm -f /tmp/scrutiny-caddy-test.$$

echo "HTTP $HTTP_CODE"

case "$HTTP_CODE" in
  200)
    echo "PASS: https://${DOMAIN} is working through Caddy."
    ;;
  *)
    echo "ERROR: clean Scrutiny route did not return HTTP 200."
    echo "Backup remains at: $BACKUP"
    echo "Inspect with: docker logs caddy --tail=100"
    exit 1
    ;;
esac

echo
 echo "=== SCRUTINY CADDY ROUTE COMPLETE ==="
