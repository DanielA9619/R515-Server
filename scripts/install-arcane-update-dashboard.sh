#!/usr/bin/env bash
set -Eeuo pipefail

ARCANE_DIR=/srv/docker/arcane
ARCANE_DATA_DIR="${ARCANE_DIR}/data"
ARCANE_BACKUP_DIR=/mnt/storage/backups/arcane
ARCANE_HOST=arcane.r515.allenfamhouse.com
CADDYFILE=/srv/docker/caddy/Caddyfile
MAIN_COMPOSE=/srv/docker/docker-compose.yml
STAMP="$(date +%Y%m%d-%H%M%S)"

section(){ printf '\n=== %s ===\n' "$1"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "Run as root on docker01."
command -v docker >/dev/null || fail "docker missing"
command -v openssl >/dev/null || fail "openssl missing"
command -v curl >/dev/null || fail "curl missing"
docker compose version >/dev/null 2>&1 || fail "docker compose plugin missing"
docker inspect caddy >/dev/null 2>&1 || fail "Caddy container is not running"
[ -f "$CADDYFILE" ] || fail "Missing $CADDYFILE"
[ -f "$MAIN_COMPOSE" ] || fail "Missing $MAIN_COMPOSE"
mountpoint -q /mnt/storage || fail "/mnt/storage is not mounted"

section "DISCOVER CADDY NETWORK"

CADDY_NET="$(
  docker inspect caddy     --format '{{range $name, $cfg := .NetworkSettings.Networks}}{{println $name}}{{end}}' |
  awk 'NF {print; exit}'
)"
[ -n "$CADDY_NET" ] || fail "Could not determine Caddy Docker network"
docker network inspect "$CADDY_NET" >/dev/null 2>&1 ||
  fail "Caddy network $CADDY_NET does not exist"

TRUSTED_PROXIES="$(
  docker network inspect "$CADDY_NET"     --format '{{range .IPAM.Config}}{{println .Subnet}}{{end}}' |
  awk 'NF {print; exit}'
)"
[ -n "$TRUSTED_PROXIES" ] || fail "Could not determine Caddy network subnet"

echo "Caddy network: $CADDY_NET"
echo "Trusted proxy CIDR: $TRUSTED_PROXIES"

section "PREPARE ARCANE DIRECTORIES"

mkdir -p "$ARCANE_DIR" "$ARCANE_DATA_DIR" "$ARCANE_BACKUP_DIR"
chmod 0755 "$ARCANE_DIR" "$ARCANE_BACKUP_DIR"
chown -R 65532:65532 "$ARCANE_DATA_DIR"
chmod 0750 "$ARCANE_DATA_DIR"

if [ -f "$ARCANE_DIR/.env" ]; then
  cp -a "$ARCANE_DIR/.env" "$ARCANE_DIR/.env.backup-$STAMP"
fi

if [ ! -s "$ARCANE_DIR/.env" ]; then
  umask 077
  cat > "$ARCANE_DIR/.env" <<EOF
ARCANE_ENCRYPTION_KEY=$(openssl rand -hex 32)
ARCANE_ADMIN_API_KEY=$(openssl rand -hex 32)
CADDY_NET=$CADDY_NET
TRUSTED_PROXIES=$TRUSTED_PROXIES
EOF
  chmod 0600 "$ARCANE_DIR/.env"
else
  grep -q '^ARCANE_ENCRYPTION_KEY=' "$ARCANE_DIR/.env" ||
    echo "ARCANE_ENCRYPTION_KEY=$(openssl rand -hex 32)" >> "$ARCANE_DIR/.env"
  grep -q '^ARCANE_ADMIN_API_KEY=' "$ARCANE_DIR/.env" ||
    echo "ARCANE_ADMIN_API_KEY=$(openssl rand -hex 32)" >> "$ARCANE_DIR/.env"

  if grep -q '^CADDY_NET=' "$ARCANE_DIR/.env"; then
    sed -i "s|^CADDY_NET=.*|CADDY_NET=$CADDY_NET|" "$ARCANE_DIR/.env"
  else
    echo "CADDY_NET=$CADDY_NET" >> "$ARCANE_DIR/.env"
  fi

  if grep -q '^TRUSTED_PROXIES=' "$ARCANE_DIR/.env"; then
    sed -i "s|^TRUSTED_PROXIES=.*|TRUSTED_PROXIES=$TRUSTED_PROXIES|" "$ARCANE_DIR/.env"
  else
    echo "TRUSTED_PROXIES=$TRUSTED_PROXIES" >> "$ARCANE_DIR/.env"
  fi

  chmod 0600 "$ARCANE_DIR/.env"
fi

PROJECT_UID="$(stat -c '%u' "$MAIN_COMPOSE")"
PROJECT_GID="$(stat -c '%g' "$MAIN_COMPOSE")"
echo "Arcane project-file runtime UID:GID: $PROJECT_UID:$PROJECT_GID"

section "WRITE ARCANE COMPOSE"

cat > "$ARCANE_DIR/compose.yaml" <<EOF
services:
  docker-socket-proxy:
    image: wollomatic/socket-proxy:1.13.1
    container_name: arcane-docker-proxy
    user: '0:0'
    command:
      - '-listenip=0.0.0.0'
      - '-allowfrom=arcane,arcane-upgrader'
      - '-allowhealthcheck'
      - '-allowGET=(/v[\\d.]+)?/_ping'
      - '-allowGET=(/v[\\d.]+)?/events(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/version'
      - '-allowGET=(/v[\\d.]+)?/info(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/system/df'
      - '-allowGET=(/v[\\d.]+)?/containers(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/exec(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/images(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/networks(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/volumes(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/distribution(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/swarm(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/nodes(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/services(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/tasks(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/secrets(/.*)?'
      - '-allowGET=(/v[\\d.]+)?/configs(/.*)?'
      - '-allowHEAD=(/v[\\d.]+)?/_ping'
      - '-allowHEAD=(/v[\\d.]+)?/version'
      - '-allowPOST=(/v[\\d.]+)?/containers(/.*)?'
      - '-allowPOST=(/v[\\d.]+)?/exec(/.*)?'
      - '-allowPOST=(/v[\\d.]+)?/images(/.*)?'
      - '-allowPOST=(/v[\\d.]+)?/networks(/.*)?'
      - '-allowPOST=(/v[\\d.]+)?/volumes(/.*)?'
      - '-allowPOST=(/v[\\d.]+)?/commit'
      - '-allowPOST=(/v[\\d.]+)?/build'
      - '-allowPOST=(/v[\\d.]+)?/session'
      - '-allowPOST=(/v[\\d.]+)?/grpc'
      - '-allowPOST=(/v[\\d.]+)?/auth'
      - '-allowPOST=(/v[\\d.]+)?/swarm(/.*)?'
      - '-allowPOST=(/v[\\d.]+)?/nodes(/.*)?'
      - '-allowPOST=(/v[\\d.]+)?/services(/.*)?'
      - '-allowPOST=(/v[\\d.]+)?/secrets(/.*)?'
      - '-allowPOST=(/v[\\d.]+)?/configs(/.*)?'
      - '-allowPUT=(/v[\\d.]+)?/containers(/.*)?/archive'
      - '-allowDELETE=(/v[\\d.]+)?/containers(/.*)?'
      - '-allowDELETE=(/v[\\d.]+)?/images(/.*)?'
      - '-allowDELETE=(/v[\\d.]+)?/networks(/.*)?'
      - '-allowDELETE=(/v[\\d.]+)?/volumes(/.*)?'
      - '-allowDELETE=(/v[\\d.]+)?/nodes(/.*)?'
      - '-allowDELETE=(/v[\\d.]+)?/services(/.*)?'
      - '-allowDELETE=(/v[\\d.]+)?/secrets(/.*)?'
      - '-allowDELETE=(/v[\\d.]+)?/configs(/.*)?'
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    read_only: true
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    healthcheck:
      test: ['CMD', './healthcheck']
      interval: 2s
      timeout: 5s
      retries: 15
    networks:
      - arcane-internal
    restart: unless-stopped

  arcane:
    image: ghcr.io/getarcaneapp/manager:v2
    container_name: arcane
    cgroup: host
    volumes:
      - ./data:/app/data
      - /srv/docker:/srv/docker
      - /mnt/storage/backups/arcane:/backups
    environment:
      APP_URL: https://$ARCANE_HOST
      TLS_ENABLED: 'false'
      TZ: America/Denver
      ENCRYPTION_KEY: ${ARCANE_ENCRYPTION_KEY}
      ADMIN_STATIC_API_KEY: ${ARCANE_ADMIN_API_KEY}
      PROJECTS_DIRECTORY: /srv/docker
      DOCKER_HOST: tcp://arcane-docker-proxy:2375
      TRUSTED_PROXIES: ${TRUSTED_PROXIES}
      PUID: '$PROJECT_UID'
      PGID: '$PROJECT_GID'
    networks:
      - arcane-internal
      - caddy-net
    depends_on:
      docker-socket-proxy:
        condition: service_healthy
    healthcheck:
      test: ['CMD', './arcane', 'health', '--timeout', '2s']
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 15s
    restart: unless-stopped

networks:
  arcane-internal:
    name: arcane-internal
    driver: bridge
  caddy-net:
    external: true
    name: ${CADDY_NET}
EOF

chmod 0644 "$ARCANE_DIR/compose.yaml"

docker compose   --env-file "$ARCANE_DIR/.env"   -f "$ARCANE_DIR/compose.yaml"   config >/dev/null

echo "PASS: Arcane Compose validates."

section "DEPLOY ARCANE"

docker compose   --env-file "$ARCANE_DIR/.env"   -f "$ARCANE_DIR/compose.yaml"   pull

docker compose   --env-file "$ARCANE_DIR/.env"   -f "$ARCANE_DIR/compose.yaml"   up -d

for _ in $(seq 1 30); do
  state="$(docker inspect arcane --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
  [ "$state" = healthy ] && break
  sleep 2
done

state="$(docker inspect arcane --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
[ "$state" = healthy ] || {
  docker logs --tail 120 arcane 2>&1 || true
  fail "Arcane did not become healthy (state=$state)"
}

echo "PASS: Arcane is healthy."

section "ADD PRIVATE CADDY ROUTE"

cp -a "$CADDYFILE" "$CADDYFILE.backup-$STAMP"
CANDIDATE="$(mktemp)"
trap 'rm -f "$CANDIDATE"' EXIT
cp -a "$CADDYFILE" "$CANDIDATE"

if grep -qF "$ARCANE_HOST" "$CANDIDATE"; then
  echo "INFO: Arcane Caddy host already exists; leaving route unchanged."
else
  cat >> "$CANDIDATE" <<EOF

$ARCANE_HOST {
    import private_only
    tls internal
    reverse_proxy arcane:3552
}
EOF
fi

docker cp "$CANDIDATE" caddy:/tmp/Caddyfile.arcane-candidate

docker exec caddy   caddy validate   --config /tmp/Caddyfile.arcane-candidate   --adapter caddyfile

cat "$CANDIDATE" > "$CADDYFILE"
docker kill --signal=USR1 caddy >/dev/null
sleep 3

echo "PASS: Caddy route installed and reloaded in-place."

section "END-TO-END VERIFY"

docker inspect arcane   --format 'Arcane: status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{end}}'

docker inspect arcane-docker-proxy   --format 'Socket proxy: status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{end}}'

curl -kfsS   --resolve "$ARCANE_HOST:443:192.168.10.135"   "https://$ARCANE_HOST/api/health" >/dev/null

echo "PASS: private HTTPS route reaches Arcane."

echo
echo "Arcane URL: https://$ARCANE_HOST"
echo "Initial username: arcane"
echo "Initial password: arcane-admin"
echo
echo "IMPORTANT: change the default password immediately after first login."
echo "Secrets are stored only in $ARCANE_DIR/.env (mode 0600)."
echo "Arcane data: $ARCANE_DATA_DIR"
echo "Arcane backups: $ARCANE_BACKUP_DIR"
echo
echo "=== ARCANE INSTALL COMPLETE ==="
