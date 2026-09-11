#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: run this script as root."
  echo "Use: sudo bash $0"
  exit 1
fi

PROM_VERSION="v3.13.3"
NODE_VERSION="1.12.1"
NODE_SHA256="b51d8a76aa2a9156a55d501aca6276fae09e262259a5e4e831d2c2222f084e63"
CADVISOR_VERSION="v0.60.5"
HOST_IP="192.168.10.135"
BASE_DIR="/srv/docker/monitoring/metrics"
NODE_DIR="/var/lib/node_exporter/textfile"
NODE_BIN="/usr/local/bin/node_exporter"

section() {
  printf '\n\n=== %s ===\n' "$1"
}

port_in_use() {
  local port="$1"
  ss -lntH | awk '{print $4}' | grep -Eq "(^|:)${port}$"
}

node_ready() {
  local tmp
  tmp="$(mktemp)"
  if curl -fsS --max-time 5 -o "$tmp" "http://${HOST_IP}:9100/metrics" \
      && grep -q '^node_cpu_seconds_total' "$tmp"; then
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

section "R515 PROMETHEUS BASE INSTALL"

echo "Prometheus:    ${PROM_VERSION}"
echo "node_exporter: v${NODE_VERSION}"
echo "cAdvisor:      ${CADVISOR_VERSION}"

section "PRECHECKS"
command -v docker >/dev/null || { echo "ERROR: docker missing"; exit 1; }
docker compose version >/dev/null
command -v curl >/dev/null || { echo "ERROR: curl missing"; exit 1; }
command -v tar >/dev/null || { echo "ERROR: tar missing"; exit 1; }
command -v sha256sum >/dev/null || { echo "ERROR: sha256sum missing"; exit 1; }

if port_in_use 9090; then
  if [ -f "${BASE_DIR}/docker-compose.yml" ] && docker ps --format '{{.Names}}' | grep -qx prometheus; then
    echo "INFO: port 9090 is already owned by the existing Prometheus deployment; continuing."
  else
    echo "ERROR: TCP port 9090 is already in use by something other than this monitoring stack."
    ss -lntp | grep ':9090' || true
    exit 1
  fi
else
  echo "PASS: port 9090 available."
fi

section "INSTALL / VERIFY NODE_EXPORTER"

if systemctl is-active --quiet node-exporter.service && node_ready; then
  echo "PASS: existing node_exporter service is active and serving host metrics."
else
  if port_in_use 9100 && ! systemctl is-active --quiet node-exporter.service; then
    echo "ERROR: TCP port 9100 is in use but node-exporter.service is not the active owner."
    ss -lntp | grep ':9100' || true
    exit 1
  fi

  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR"' EXIT
  NODE_ARCHIVE="node_exporter-${NODE_VERSION}.linux-amd64.tar.gz"
  NODE_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/${NODE_ARCHIVE}"

  curl -fL "$NODE_URL" -o "${TMPDIR}/${NODE_ARCHIVE}"
  echo "${NODE_SHA256}  ${TMPDIR}/${NODE_ARCHIVE}" | sha256sum -c -
  tar -xzf "${TMPDIR}/${NODE_ARCHIVE}" -C "$TMPDIR"
  install -m 0755 "${TMPDIR}/node_exporter-${NODE_VERSION}.linux-amd64/node_exporter" "$NODE_BIN"
  mkdir -p "$NODE_DIR"
  chmod 0755 /var/lib/node_exporter "$NODE_DIR"

  cat > /etc/systemd/system/node-exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter for docker01
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=nobody
Group=nogroup
ExecStart=${NODE_BIN} --web.listen-address=${HOST_IP}:9100 --collector.textfile.directory=${NODE_DIR}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now node-exporter.service

  for i in $(seq 1 20); do
    if node_ready; then
      echo "PASS: node_exporter is serving host metrics."
      break
    fi
    if [ "$i" -eq 20 ]; then
      echo "ERROR: node_exporter did not become ready."
      systemctl status node-exporter.service --no-pager -l || true
      exit 1
    fi
    sleep 1
  done
fi

section "CREATE PROMETHEUS + CADVISOR STACK"
mkdir -p "${BASE_DIR}/prometheus/data"
chown -R 65534:65534 "${BASE_DIR}/prometheus/data"

cat > "${BASE_DIR}/prometheus/prometheus.yml" <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['prometheus:9090']

  - job_name: docker01
    static_configs:
      - targets: ['${HOST_IP}:9100']
        labels:
          host: docker01

  - job_name: cadvisor
    static_configs:
      - targets: ['cadvisor:8080']
        labels:
          host: docker01
EOF

cat > "${BASE_DIR}/docker-compose.yml" <<EOF
services:
  prometheus:
    image: prom/prometheus:${PROM_VERSION}
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "${HOST_IP}:9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/data:/prometheus
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=15d

  cadvisor:
    image: ghcr.io/google/cadvisor:${CADVISOR_VERSION}
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    devices:
      - /dev/kmsg:/dev/kmsg
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
      - /dev/disk:/dev/disk:ro
EOF

cd "$BASE_DIR"
docker compose config >/dev/null
echo "PASS: Compose valid."

docker compose pull
docker compose up -d

section "VALIDATE PROMETHEUS"
for i in $(seq 1 30); do
  if curl -fsS --max-time 3 "http://${HOST_IP}:9090/-/ready" >/dev/null 2>&1; then
    echo "PASS: Prometheus ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Prometheus did not become ready."
    docker compose ps || true
    docker compose logs --tail=120 prometheus cadvisor || true
    exit 1
  fi
  sleep 2
done

sleep 18

python3 - <<PY
import json
import urllib.request

url = 'http://${HOST_IP}:9090/api/v1/targets'
with urllib.request.urlopen(url, timeout=5) as r:
    data = json.load(r)

targets = data.get('data', {}).get('activeTargets', [])
print('\nPrometheus targets:')
failed = []
for t in targets:
    labels = t.get('labels', {})
    job = labels.get('job', '?')
    health = t.get('health', '?')
    scrape = t.get('scrapeUrl', '?')
    print(f'  {job:12} {health:8} {scrape}')
    if health != 'up':
        failed.append(job)

expected = {'prometheus', 'docker01', 'cadvisor'}
seen = {t.get('labels', {}).get('job') for t in targets}
missing = expected - seen
if failed or missing:
    print(f'\nWARN: failed={failed} missing={sorted(missing)}')
    raise SystemExit(2)
print('\nPASS: all three base scrape targets are UP.')
PY

section "STATUS"
systemctl status node-exporter.service --no-pager -l | sed -n '1,18p' || true
docker compose ps

echo
echo "Prometheus direct URL: http://${HOST_IP}:9090"
echo "node_exporter:         http://${HOST_IP}:9100/metrics"
echo "cAdvisor:              internal Docker network only"
echo
echo "=== PROMETHEUS BASE INSTALL COMPLETE ==="
