#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "This script must run as root."
  echo "Use: sudo bash $0"
  exit 1
fi

SCRUTINY_VERSION="v0.9.3"
BASE_DIR="/srv/docker/monitoring/scrutiny"
HOST_IP="192.168.10.135"
HOST_PORT="8082"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: docker compose plugin is not available."
  exit 1
fi

if ss -lntH | awk '{print $4}' | grep -Eq "(^|:)${HOST_PORT}$"; then
  echo "ERROR: TCP port ${HOST_PORT} is already in use."
  ss -lntp | grep -E "(^|:)${HOST_PORT}[[:space:]]" || true
  exit 1
fi

mkdir -p "${BASE_DIR}/config" "${BASE_DIR}/influxdb"

cat > "${BASE_DIR}/docker-compose.yml" <<YAML
services:
  influxdb:
    image: influxdb:2.8
    container_name: scrutiny-influxdb
    restart: unless-stopped
    volumes:
      - ./influxdb:/var/lib/influxdb2
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8086/health"]
      interval: 5s
      timeout: 10s
      retries: 20

  web:
    image: ghcr.io/analogj/scrutiny:${SCRUTINY_VERSION}-web
    container_name: scrutiny-web
    restart: unless-stopped
    ports:
      - "${HOST_IP}:${HOST_PORT}:8080"
    volumes:
      - ./config:/opt/scrutiny/config
    environment:
      SCRUTINY_WEB_INFLUXDB_HOST: influxdb
    depends_on:
      influxdb:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/health"]
      interval: 5s
      timeout: 10s
      retries: 20
      start_period: 10s
YAML

cd "${BASE_DIR}"
docker compose config >/dev/null
docker compose pull
docker compose up -d

echo
echo "Waiting for Scrutiny web health..."
for i in $(seq 1 30); do
  if curl -fsS --max-time 3 "http://${HOST_IP}:${HOST_PORT}/api/health" >/dev/null 2>&1; then
    echo "PASS: Scrutiny hub is healthy."
    echo "Direct URL: http://${HOST_IP}:${HOST_PORT}"
    docker compose ps
    exit 0
  fi
  sleep 2
done

echo "ERROR: Scrutiny did not become healthy in time."
docker compose ps || true
docker compose logs --tail=120 web influxdb || true
exit 1
