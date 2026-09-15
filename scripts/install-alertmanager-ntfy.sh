#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: run this script as root."
  echo "Use: sudo bash $0"
  exit 1
fi

HOST_IP="192.168.10.135"
ALERTMANAGER_VERSION="v0.34.0"
PROMETHEUS_VERSION="v3.13.3"
METRICS_DIR="/srv/docker/monitoring/metrics"
PROM_CONFIG="${METRICS_DIR}/prometheus/prometheus.yml"
PROM_RULES="${METRICS_DIR}/prometheus/r515-alerts.yml"
PROM_COMPOSE="${METRICS_DIR}/docker-compose.yml"
ALERT_DIR="/srv/docker/monitoring/alerting"
TOPIC_FILE="${ALERT_DIR}/ntfy-topic.txt"
STAMP="$(date +%Y%m%d-%H%M%S)"

section() {
  printf '\n=== %s ===\n' "$1"
}

section "R515 ALERTMANAGER + NTFY INSTALL"

echo "Alertmanager: ${ALERTMANAGER_VERSION}"
echo "Delivery:     hosted ntfy.sh topic"

section "PRECHECKS"
command -v docker >/dev/null || { echo "ERROR: docker missing"; exit 1; }
command -v curl >/dev/null || { echo "ERROR: curl missing"; exit 1; }
command -v openssl >/dev/null || { echo "ERROR: openssl missing"; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: python3 missing"; exit 1; }

docker compose version >/dev/null

[ -f "$PROM_CONFIG" ] || { echo "ERROR: missing $PROM_CONFIG"; exit 1; }
[ -f "$PROM_COMPOSE" ] || { echo "ERROR: missing $PROM_COMPOSE"; exit 1; }

curl -fsS --max-time 5 "http://${HOST_IP}:9090/-/ready" >/dev/null || {
  echo "ERROR: Prometheus is not ready."
  exit 1
}

echo "PASS: Prometheus ready."

if ss -lntH | awk '{print $4}' | grep -Eq '(^|:)9093$'; then
  if docker ps --format '{{.Names}}' | grep -qx alertmanager; then
    echo "INFO: existing Alertmanager container detected."
  else
    echo "ERROR: TCP port 9093 is already in use."
    ss -lntp | grep ':9093' || true
    exit 1
  fi
else
  echo "PASS: port 9093 available."
fi

section "CREATE LOCAL NTFY TOPIC"
mkdir -p "$ALERT_DIR"

if [ ! -s "$TOPIC_FILE" ]; then
  umask 077
  printf 'r515-%s\n' "$(openssl rand -hex 18)" > "$TOPIC_FILE"
  chmod 0600 "$TOPIC_FILE"
  echo "Created a new random ntfy topic."
else
  echo "Existing ntfy topic retained."
fi

TOPIC="$(tr -d '\r\n' < "$TOPIC_FILE")"
[ -n "$TOPIC" ] || { echo "ERROR: ntfy topic is empty."; exit 1; }

echo "Topic stored locally at: $TOPIC_FILE"
echo "Topic value is intentionally not printed."

section "WRITE ALERTMANAGER CONFIG"
mkdir -p "${ALERT_DIR}/data"
chown -R 65534:65534 "${ALERT_DIR}/data"

cat > "${ALERT_DIR}/alertmanager.yml" <<EOF
global:
  resolve_timeout: 5m

route:
  receiver: ntfy
  group_by:
    - alertname
    - severity
  group_wait: 20s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: ntfy
    webhook_configs:
      - url: "https://ntfy.sh/${TOPIC}?template=alertmanager"
        send_resolved: true
EOF

cat > "${ALERT_DIR}/docker-compose.yml" <<EOF
services:
  alertmanager:
    image: prom/alertmanager:${ALERTMANAGER_VERSION}
    container_name: alertmanager
    restart: unless-stopped

    ports:
      - "${HOST_IP}:9093:9093"

    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - ./data:/alertmanager

    command:
      - --config.file=/etc/alertmanager/alertmanager.yml
      - --storage.path=/alertmanager
EOF

cd "$ALERT_DIR"
docker compose config >/dev/null
echo "PASS: Alertmanager Compose valid."

docker pull "prom/alertmanager:${ALERTMANAGER_VERSION}"

docker run --rm \
  --entrypoint /bin/amtool \
  -v "${ALERT_DIR}/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro" \
  "prom/alertmanager:${ALERTMANAGER_VERSION}" \
  check-config /etc/alertmanager/alertmanager.yml >/dev/null

echo "PASS: Alertmanager configuration valid."

section "WRITE PROMETHEUS ALERT RULES"
cat > "$PROM_RULES" <<'EOF'
groups:
  - name: r515-health
    interval: 30s
    rules:
      - alert: R515StorageNotMounted
        expr: r515_storage_mounted == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: R515 storage is not mounted
          description: /mnt/storage is not mounted as the expected filesystem.

      - alert: R515StorageNotWritable
        expr: r515_storage_writable == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: R515 storage is not writable
          description: The real write test to /mnt/storage is failing.

      - alert: R515GluetunUnhealthy
        expr: r515_gluetun_healthy == 0
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: Gluetun VPN is unhealthy
          description: Docker no longer reports the Gluetun container as healthy.

      - alert: R515ByparrUnhealthy
        expr: r515_byparr_health == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: Byparr health check is failing
          description: The real Byparr /health endpoint is not responding successfully.

      - alert: R515PostbootRecoveryFailed
        expr: r515_postboot_recovery_success == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: Post-boot recovery is not successful
          description: r515-postboot-recovery.service is not active with exit status 0.

      - alert: R515ByparrRecoveryFailed
        expr: r515_byparr_recovery_success == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: Byparr recovery is not successful
          description: r515-byparr-recovery.service is not active with exit status 0.

      - alert: R515ConfigBackupMissing
        expr: r515_config_backup_present == 0
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: No R515 config backup was found
          description: No matching r515-configs backup archive exists under /mnt/storage/backups.

      - alert: R515ConfigBackupStale
        expr: r515_config_backup_age_seconds > 604800 and r515_config_backup_age_seconds <= 1209600
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: R515 config backup is more than 7 days old
          description: The newest R515 config backup should be refreshed.

      - alert: R515ConfigBackupVeryStale
        expr: r515_config_backup_age_seconds > 1209600
        for: 30m
        labels:
          severity: critical
        annotations:
          summary: R515 config backup is more than 14 days old
          description: The newest R515 config backup is critically stale.

      - alert: R515CustomMetricsMissing
        expr: absent(r515_metrics_generated_unixtime)
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: R515 custom metrics are missing
          description: Prometheus can no longer see the custom R515 metrics file.

      - alert: R515CustomMetricsStale
        expr: time() - r515_metrics_generated_unixtime > 180
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: R515 custom metrics are stale
          description: The custom metrics collector has not refreshed for more than 3 minutes.

      - alert: Docker01NodeExporterDown
        expr: up{job="docker01"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: docker01 node_exporter is down
          description: Prometheus cannot scrape docker01 host metrics.

      - alert: Docker01CadvisorDown
        expr: up{job="cadvisor"} == 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: docker01 cAdvisor is down
          description: Prometheus cannot scrape Docker container metrics.

      - alert: R515StorageLowFreeSpace
        expr: node_filesystem_avail_bytes{job="docker01",mountpoint="/mnt/storage"} < 214748364800
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: R515 storage has less than 200 GiB free
          description: Free capacity on /mnt/storage has dropped below 200 GiB.
EOF

section "PATCH PROMETHEUS CONFIG"
cp -a "$PROM_CONFIG" "${PROM_CONFIG}.pre-alerting-${STAMP}"
cp -a "$PROM_COMPOSE" "${PROM_COMPOSE}.pre-alerting-${STAMP}"

if grep -q '^alerting:' "$PROM_CONFIG" && ! grep -q '192.168.10.135:9093' "$PROM_CONFIG"; then
  echo "ERROR: Prometheus already has an alerting block that this installer did not create."
  echo "Merge manually instead of risking an overwrite."
  exit 1
fi

if grep -q '^rule_files:' "$PROM_CONFIG" && ! grep -q '/etc/prometheus/r515-alerts.yml' "$PROM_CONFIG"; then
  echo "ERROR: Prometheus already has rule_files that this installer did not create."
  echo "Merge manually instead of risking an overwrite."
  exit 1
fi

python3 - "$PROM_CONFIG" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()

if '/etc/prometheus/r515-alerts.yml' not in s:
    marker = 'scrape_configs:\n'
    if marker not in s:
        raise SystemExit('ERROR: scrape_configs marker not found')
    block = '''rule_files:\n  - /etc/prometheus/r515-alerts.yml\n\nalerting:\n  alertmanagers:\n    - static_configs:\n        - targets:\n            - 192.168.10.135:9093\n\n'''
    s = s.replace(marker, block + marker, 1)

p.write_text(s)
PY

python3 - "$PROM_COMPOSE" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()
mount = '      - ./prometheus/r515-alerts.yml:/etc/prometheus/r515-alerts.yml:ro\n'

if 'r515-alerts.yml:/etc/prometheus/r515-alerts.yml:ro' not in s:
    marker = '      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro\n'
    if marker not in s:
        raise SystemExit('ERROR: Prometheus config mount marker not found')
    s = s.replace(marker, marker + mount, 1)

p.write_text(s)
PY

cd "$METRICS_DIR"
docker compose config >/dev/null

docker run --rm \
  --entrypoint /bin/promtool \
  -v "${METRICS_DIR}/prometheus:/etc/prometheus:ro" \
  "prom/prometheus:${PROMETHEUS_VERSION}" \
  check config /etc/prometheus/prometheus.yml >/dev/null

echo "PASS: Prometheus config and alert rules valid."

section "START ALERTMANAGER"
cd "$ALERT_DIR"
docker compose up -d

for i in $(seq 1 30); do
  if curl -fsS --max-time 3 "http://${HOST_IP}:9093/-/ready" >/dev/null 2>&1; then
    echo "PASS: Alertmanager ready."
    break
  fi

  if [ "$i" -eq 30 ]; then
    echo "ERROR: Alertmanager did not become ready."
    docker compose ps || true
    docker compose logs --tail=120 alertmanager || true
    exit 1
  fi

  sleep 2
done

section "RECREATE PROMETHEUS WITH ALERTING MOUNT"
cd "$METRICS_DIR"
docker compose up -d --no-deps --force-recreate prometheus

for i in $(seq 1 30); do
  if curl -fsS --max-time 3 "http://${HOST_IP}:9090/-/ready" >/dev/null 2>&1; then
    echo "PASS: Prometheus ready after alerting configuration."
    break
  fi

  if [ "$i" -eq 30 ]; then
    echo "ERROR: Prometheus did not become ready."
    docker compose logs --tail=120 prometheus || true
    exit 1
  fi

  sleep 2
done

sleep 5

section "VERIFY PROMETHEUS ALERTMANAGER DISCOVERY"
python3 - <<PY
import json
import urllib.request

url = 'http://${HOST_IP}:9090/api/v1/alertmanagers'
with urllib.request.urlopen(url, timeout=5) as r:
    data = json.load(r)
active = data.get('data', {}).get('activeAlertmanagers', [])
print('Active Alertmanagers:')
for item in active:
    print(' ', item.get('url', '?'))
if not any('192.168.10.135:9093' in item.get('url', '') for item in active):
    raise SystemExit('ERROR: Prometheus has not discovered Alertmanager.')
print('PASS: Prometheus sees Alertmanager.')
PY

section "VERIFY ALERT RULES"
RULES_JSON="$(mktemp)"
trap 'rm -f "$RULES_JSON"' EXIT
curl -fsS --max-time 5 -o "$RULES_JSON" "http://${HOST_IP}:9090/api/v1/rules"
grep -q 'R515StorageNotMounted' "$RULES_JSON" || {
  echo "ERROR: R515 alert rules were not loaded."
  exit 1
}
echo "PASS: R515 alert rules loaded."

section "SUBMIT END-TO-END TEST ALERT"
STARTS_AT="$(date --iso-8601=seconds)"
ENDS_AT="$(date --iso-8601=seconds -d '+2 minutes')"

python3 - "$STARTS_AT" "$ENDS_AT" > /tmp/r515-alert-test.json <<'PY'
import json
import sys

starts, ends = sys.argv[1], sys.argv[2]
print(json.dumps([{
    'labels': {
        'alertname': 'R515AlertPipelineTest',
        'severity': 'info',
        'instance': 'docker01'
    },
    'annotations': {
        'summary': 'R515 alert pipeline test',
        'description': 'Alertmanager successfully received the manual R515 test alert.'
    },
    'startsAt': starts,
    'endsAt': ends
}]))
PY

curl -fsS \
  -H 'Content-Type: application/json' \
  -X POST \
  --data-binary @/tmp/r515-alert-test.json \
  "http://${HOST_IP}:9093/api/v2/alerts" >/dev/null
rm -f /tmp/r515-alert-test.json

echo "PASS: test alert accepted by Alertmanager."
echo "Alertmanager will forward it to ntfy after the 20-second group wait."

section "STATUS"
echo "Alertmanager: http://${HOST_IP}:9093"
echo "Health:       http://${HOST_IP}:9093/-/ready"
echo "ntfy topic:   stored in ${TOPIC_FILE}"
echo
echo "To reveal the topic only when adding it to your phone:"
echo "  cat ${TOPIC_FILE}"
echo
echo "Subscribe in the ntfy app using server https://ntfy.sh and that topic."
echo "Do not paste the topic into GitHub or public logs; the random topic acts like a secret."
echo
echo "=== R515 ALERTMANAGER + NTFY INSTALL COMPLETE ==="
