#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: run this script as root on docker01."
  exit 1
fi

HOST_IP="192.168.10.135"
PVE_IP="192.168.10.50"
PVE_USER="prometheus@pve"
PVE_TOKEN_NAME="r515-monitoring"
EXPORTER_VERSION="3.9.0"
EXPORTER_DIR="/srv/docker/monitoring/proxmox-exporter"
ENV_FILE="${EXPORTER_DIR}/.env"
PROM_DIR="/srv/docker/monitoring/metrics"
PROM_CONFIG="${PROM_DIR}/prometheus/prometheus.yml"
STAMP="$(date +%Y%m%d-%H%M%S)"

section() {
  printf '\n=== %s ===\n' "$1"
}

section "R515 PROXMOX EXPORTER INSTALL"

command -v docker >/dev/null || { echo "ERROR: docker missing"; exit 1; }
command -v curl >/dev/null || { echo "ERROR: curl missing"; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: python3 missing"; exit 1; }
[ -f "$PROM_CONFIG" ] || { echo "ERROR: missing $PROM_CONFIG"; exit 1; }

curl -kfsS --max-time 5 "https://${PVE_IP}:8006/api2/json/version" >/dev/null || {
  echo "ERROR: cannot reach the Proxmox API at ${PVE_IP}:8006."
  exit 1
}
echo "PASS: Proxmox API reachable."

mkdir -p "$EXPORTER_DIR"

section "LOCAL SECRET"
if [ -s "$ENV_FILE" ] && grep -q '^PVE_TOKEN_VALUE=' "$ENV_FILE"; then
  echo "INFO: existing local token secret retained."
else
  read -rsp "Paste the Proxmox token VALUE (input hidden): " TOKEN_VALUE
  echo
  [ -n "$TOKEN_VALUE" ] || { echo "ERROR: token value is empty"; exit 1; }

  OLD_UMASK="$(umask)"
  umask 077
  cat > "$ENV_FILE" <<EOF
PVE_USER=${PVE_USER}
PVE_TOKEN_NAME=${PVE_TOKEN_NAME}
PVE_TOKEN_VALUE=${TOKEN_VALUE}
PVE_VERIFY_SSL=false
PVE_MODULE=default
EOF
  chmod 0600 "$ENV_FILE"
  umask "$OLD_UMASK"
  unset TOKEN_VALUE
  echo "PASS: token stored locally in ${ENV_FILE} (mode 0600)."
fi

section "EXPORTER COMPOSE"
cat > "${EXPORTER_DIR}/docker-compose.yml" <<EOF
services:
  pve-exporter:
    image: prompve/prometheus-pve-exporter:${EXPORTER_VERSION}
    container_name: pve-exporter
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "${HOST_IP}:9221:9221"
    command:
      - --web.listen-address
      - 0.0.0.0:9221
EOF
chmod 0644 "${EXPORTER_DIR}/docker-compose.yml"

cd "$EXPORTER_DIR"
docker compose config >/dev/null
docker compose pull
docker compose up -d

for i in $(seq 1 30); do
  if curl -fsS --max-time 3 "http://${HOST_IP}:9221/metrics" >/dev/null 2>&1; then
    echo "PASS: exporter HTTP endpoint ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: exporter did not become ready."
    docker compose ps || true
    docker compose logs --tail=120 pve-exporter || true
    exit 1
  fi
  sleep 2
done

section "VERIFY PROXMOX API SCRAPE"
PVE_TEST="$(mktemp)"
trap 'rm -f "$PVE_TEST"' EXIT

if ! curl -fsS --max-time 20 \
  "http://${HOST_IP}:9221/pve?target=${PVE_IP}&module=default&cluster=1&node=1" \
  -o "$PVE_TEST"; then
  echo "ERROR: exporter could not collect from Proxmox."
  docker compose logs --tail=120 pve-exporter || true
  exit 1
fi

grep -q '^pve_up' "$PVE_TEST" || {
  echo "ERROR: scrape returned no pve_up metrics."
  docker compose logs --tail=120 pve-exporter || true
  exit 1
}

echo "PASS: exporter is collecting Proxmox metrics."

echo "Observed pve_up series:"
grep '^pve_up' "$PVE_TEST" | head -n 20

section "PATCH PROMETHEUS"
cp -a "$PROM_CONFIG" "${PROM_CONFIG}.pre-proxmox-${STAMP}"

python3 - "$PROM_CONFIG" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()

if re.search(r"(?m)^\s*-\s*job_name:\s*['\"]?proxmox['\"]?\s*$", text):
    print("INFO: Prometheus proximoх job already exists; leaving config unchanged.")
    raise SystemExit(0)

lines = text.splitlines(keepends=True)
try:
    start = next(i for i, line in enumerate(lines) if line.startswith("scrape_configs:"))
except StopIteration:
    raise SystemExit("ERROR: scrape_configs not found")

end = len(lines)
for i in range(start + 1, len(lines)):
    line = lines[i]
    if line.strip() and not line.startswith((" ", "\t", "#")):
        end = i
        break

block = '''\n  - job_name: 'proxmox'\n    scrape_interval: 30s\n    scrape_timeout: 20s\n    metrics_path: /pve\n    params:\n      module: [default]\n      cluster: ['1']\n      node: ['1']\n    static_configs:\n      - targets:\n          - 192.168.10.50\n    relabel_configs:\n      - source_labels: [__address__]\n        target_label: __param_target\n      - source_labels: [__param_target]\n        target_label: instance\n      - target_label: __address__\n        replacement: 192.168.10.135:9221\n'''

lines.insert(end, block)
path.write_text(''.join(lines))
print("PASS: Prometheus Proxmox scrape job added.")
PY

cd "$PROM_DIR"
docker compose config >/dev/null

docker run --rm \
  --entrypoint /bin/promtool \
  -v "${PROM_DIR}/prometheus:/etc/prometheus:ro" \
  prom/prometheus:v3.13.3 \
  check config /etc/prometheus/prometheus.yml >/dev/null

echo "PASS: Prometheus config valid."

section "RECREATE PROMETHEUS"
docker compose up -d --no-deps --force-recreate prometheus

for i in $(seq 1 30); do
  if curl -fsS --max-time 3 "http://${HOST_IP}:9090/-/ready" >/dev/null 2>&1; then
    echo "PASS: Prometheus ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Prometheus did not become ready."
    docker compose logs --tail=120 prometheus || true
    exit 1
  fi
  sleep 2
done

section "VERIFY PROMETHEUS TARGET"
python3 - <<PY
import json
import time
import urllib.request

url = 'http://${HOST_IP}:9090/api/v1/targets'
for _ in range(12):
    with urllib.request.urlopen(url, timeout=5) as r:
        data = json.load(r)
    matches = [t for t in data.get('data', {}).get('activeTargets', []) if t.get('labels', {}).get('job') == 'proxmox']
    if matches and matches[0].get('health') == 'up':
        print('PASS: Prometheus target proximoх is UP.')
        print('Target:', matches[0].get('scrapeUrl', '?'))
        break
    time.sleep(5)
else:
    if matches:
        print('Last error:', matches[0].get('lastError', 'unknown'))
    raise SystemExit('ERROR: Proxmox target did not become UP.')
PY

section "LIVE PROXMOX SERIES"
sleep 5
python3 - <<PY
import json
import urllib.parse
import urllib.request

base = 'http://${HOST_IP}:9090/api/v1/query?'
queries = ['pve_up', 'pve_guest_info', 'pve_cpu_usage_ratio', 'pve_memory_usage_bytes']
for q in queries:
    url = base + urllib.parse.urlencode({'query': q})
    with urllib.request.urlopen(url, timeout=5) as r:
        payload = json.load(r)
    rows = payload.get('data', {}).get('result', [])
    print(f'\n{q}: {len(rows)} series')
    for row in rows[:12]:
        labels = row.get('metric', {})
        value = row.get('value', [None, '?'])[1]
        wanted = {k: labels[k] for k in ('id','name','node','type','instance') if k in labels}
        print(' ', wanted, '=', value)
PY

echo
echo "=== PROXMOX EXPORTER INSTALL COMPLETE ==="
echo "Exporter:   http://${HOST_IP}:9221"
echo "Prometheus: job=proxmox"
echo "Token:      stored locally; never printed"
