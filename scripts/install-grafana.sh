#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: run this script as root."
  echo "Use: sudo bash $0"
  exit 1
fi

GRAFANA_VERSION="13.2.1"
HOST_IP="192.168.10.135"
HOST_PORT="3003"
PROMETHEUS_URL="http://192.168.10.135:9090"
BASE_DIR="/srv/docker/monitoring/grafana"

section() {
  printf '\n\n=== %s ===\n' "$1"
}

section "R515 GRAFANA INSTALL"
echo "Grafana: ${GRAFANA_VERSION}"

section "PRECHECKS"
command -v docker >/dev/null || { echo "ERROR: docker missing"; exit 1; }
docker compose version >/dev/null
command -v curl >/dev/null || { echo "ERROR: curl missing"; exit 1; }
command -v openssl >/dev/null || { echo "ERROR: openssl missing"; exit 1; }

if ! curl -fsS --max-time 5 "${PROMETHEUS_URL}/-/ready" >/dev/null; then
  echo "ERROR: Prometheus is not ready at ${PROMETHEUS_URL}."
  exit 1
fi
echo "PASS: Prometheus ready."

if ss -lntH | awk '{print $4}' | grep -Eq "(^|:)${HOST_PORT}$"; then
  if docker ps --format '{{.Names}}' | grep -qx grafana; then
    echo "INFO: existing Grafana container detected; continuing."
  else
    echo "ERROR: TCP port ${HOST_PORT} is already in use."
    ss -lntp | grep ":${HOST_PORT}" || true
    exit 1
  fi
else
  echo "PASS: port ${HOST_PORT} available."
fi

section "DIRECTORIES"
mkdir -p \
  "${BASE_DIR}/data" \
  "${BASE_DIR}/provisioning/datasources" \
  "${BASE_DIR}/provisioning/dashboards" \
  "${BASE_DIR}/dashboards"

chown -R 472:0 "${BASE_DIR}/data"
chmod 0755 "${BASE_DIR}/provisioning" \
  "${BASE_DIR}/provisioning/datasources" \
  "${BASE_DIR}/provisioning/dashboards" \
  "${BASE_DIR}/dashboards"

section "LOCAL ADMIN SECRET"
if [ ! -f "${BASE_DIR}/.env" ]; then
  ADMIN_PASSWORD="$(openssl rand -hex 24)"
  cat > "${BASE_DIR}/.env" <<EOF
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF
  chmod 0600 "${BASE_DIR}/.env"
  echo "Created new local Grafana admin credential file."
else
  echo "Existing Grafana credential file retained."
fi

ADMIN_USER="$(awk -F= '$1=="GF_SECURITY_ADMIN_USER" {print substr($0,index($0,"=")+1); exit}' "${BASE_DIR}/.env")"
ADMIN_PASSWORD="$(awk -F= '$1=="GF_SECURITY_ADMIN_PASSWORD" {print substr($0,index($0,"=")+1); exit}' "${BASE_DIR}/.env")"

[ -n "$ADMIN_USER" ] || { echo "ERROR: admin user missing from .env"; exit 1; }
[ -n "$ADMIN_PASSWORD" ] || { echo "ERROR: admin password missing from .env"; exit 1; }

section "PROVISION PROMETHEUS"
cat > "${BASE_DIR}/provisioning/datasources/prometheus.yml" <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: ${PROMETHEUS_URL}
    isDefault: true
    editable: false
    jsonData:
      httpMethod: POST
      prometheusType: Prometheus
EOF

cat > "${BASE_DIR}/provisioning/dashboards/r515.yml" <<'EOF'
apiVersion: 1

providers:
  - name: R515
    orgId: 1
    folder: R515
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

section "WRITE COMPOSE"
cat > "${BASE_DIR}/docker-compose.yml" <<EOF
services:
  grafana:
    image: grafana/grafana:${GRAFANA_VERSION}
    container_name: grafana
    restart: unless-stopped
    ports:
      - "${HOST_IP}:${HOST_PORT}:3000"
    env_file:
      - .env
    environment:
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_AUTH_ANONYMOUS_ENABLED: "false"
      GF_ANALYTICS_REPORTING_ENABLED: "false"
      GF_SECURITY_DISABLE_GRAVATAR: "true"
    volumes:
      - ./data:/var/lib/grafana
      - ./provisioning:/etc/grafana/provisioning:ro
      - ./dashboards:/var/lib/grafana/dashboards:ro
EOF

cd "$BASE_DIR"
docker compose config >/dev/null
echo "PASS: Compose valid."

section "START GRAFANA"
docker compose pull
docker compose up -d

section "WAIT FOR HEALTH"
for i in $(seq 1 40); do
  if curl -fsS --max-time 3 "http://${HOST_IP}:${HOST_PORT}/api/health" >/tmp/grafana-health.json 2>/dev/null; then
    if grep -q '"database"[[:space:]]*:[[:space:]]*"ok"' /tmp/grafana-health.json; then
      echo "PASS: Grafana API and database healthy."
      break
    fi
  fi

  if [ "$i" -eq 40 ]; then
    echo "ERROR: Grafana did not become healthy."
    docker compose ps || true
    docker compose logs --tail=150 grafana || true
    exit 1
  fi

  sleep 2
done

section "VERIFY PROMETHEUS DATASOURCE"
if curl -fsS --max-time 5 \
  -u "${ADMIN_USER}:${ADMIN_PASSWORD}" \
  "http://${HOST_IP}:${HOST_PORT}/api/datasources/uid/prometheus" \
  >/tmp/grafana-prometheus.json; then
  echo "PASS: provisioned Prometheus datasource is present."
else
  echo "ERROR: provisioned Prometheus datasource not found."
  docker compose logs --tail=120 grafana || true
  exit 1
fi

section "STATUS"
docker compose ps

echo
echo "Grafana direct URL: http://${HOST_IP}:${HOST_PORT}"
echo "Username: ${ADMIN_USER}"
echo "Password: ${ADMIN_PASSWORD}"
echo
echo "Save the password in your password manager."
echo "Credential file on server: ${BASE_DIR}/.env"
echo
echo "=== GRAFANA INSTALL COMPLETE ==="
