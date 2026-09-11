#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: run this script as root."
  echo "Use: sudo bash $0"
  exit 1
fi

COLLECTOR=/usr/local/sbin/r515-custom-metrics.sh
TEXTFILE_DIR=/var/lib/node_exporter/textfile
METRICS_FILE=${TEXTFILE_DIR}/r515.prom
HOST_IP=192.168.10.135

section() {
  printf '\n=== %s ===\n' "$1"
}

section "R515 CUSTOM PROMETHEUS METRICS"

section "PRECHECKS"
command -v docker >/dev/null || { echo "ERROR: docker missing"; exit 1; }
command -v curl >/dev/null || { echo "ERROR: curl missing"; exit 1; }
command -v findmnt >/dev/null || { echo "ERROR: findmnt missing"; exit 1; }
command -v mountpoint >/dev/null || { echo "ERROR: mountpoint missing"; exit 1; }

systemctl is-active --quiet node-exporter.service || {
  echo "ERROR: node-exporter.service is not active."
  exit 1
}

mkdir -p "$TEXTFILE_DIR"
chmod 0755 /var/lib/node_exporter "$TEXTFILE_DIR"
echo "PASS: node_exporter textfile collector is available."

section "INSTALL COLLECTOR"
cat > "$COLLECTOR" <<'COLLECTOR_SCRIPT'
#!/usr/bin/env bash
set -u

OUTDIR=/var/lib/node_exporter/textfile
OUT=${OUTDIR}/r515.prom
TMP=${OUT}.tmp.$$
STORAGE=/mnt/storage
BACKUP_ROOT=/mnt/storage/backups
NOW=$(date +%s)

mkdir -p "$OUTDIR"
trap 'rm -f "$TMP"' EXIT

storage_mounted=0
storage_writable=0

if mountpoint -q "$STORAGE" && [ "$(findmnt -rn -T "$STORAGE" -o TARGET 2>/dev/null | head -n1)" = "$STORAGE" ]; then
  storage_mounted=1

  write_test=$(mktemp "$STORAGE/.r515-metrics-write-test.XXXXXX" 2>/dev/null || true)
  if [ -n "${write_test:-}" ]; then
    if printf 'ok\n' > "$write_test" 2>/dev/null; then
      storage_writable=1
    fi
    rm -f "$write_test" 2>/dev/null || true
  fi
fi

gluetun_healthy=0
gluetun_state=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' gluetun 2>/dev/null || true)
if [ "$gluetun_state" = "healthy" ]; then
  gluetun_healthy=1
fi

byparr_health=0
if curl -fsS --max-time 10 http://127.0.0.1:8191/health >/dev/null 2>&1; then
  byparr_health=1
fi

unit_success() {
  unit="$1"
  active=$(systemctl show "$unit" -p ActiveState --value 2>/dev/null || true)
  status=$(systemctl show "$unit" -p ExecMainStatus --value 2>/dev/null || true)

  if [ "$active" = "active" ] && [ "$status" = "0" ]; then
    printf '1'
  else
    printf '0'
  fi
}

postboot_success=$(unit_success r515-postboot-recovery.service)
byparr_recovery_success=$(unit_success r515-byparr-recovery.service)

backup_present=0
backup_age=-1

if [ "$storage_mounted" -eq 1 ] && [ -d "$BACKUP_ROOT" ]; then
  latest_backup_epoch=$(
    find "$BACKUP_ROOT" -type f -name 'r515-configs-*.tar.gz' -printf '%T@\n' 2>/dev/null |
      sort -nr |
      head -n1 |
      cut -d. -f1
  )

  if [ -n "${latest_backup_epoch:-}" ]; then
    backup_present=1
    backup_age=$((NOW - latest_backup_epoch))
    if [ "$backup_age" -lt 0 ]; then
      backup_age=0
    fi
  fi
fi

cat > "$TMP" <<EOF
# HELP r515_metrics_collector_success Whether the R515 custom metrics collector completed.
# TYPE r515_metrics_collector_success gauge
r515_metrics_collector_success 1
# HELP r515_metrics_generated_unixtime Unix timestamp when these R515 metrics were generated.
# TYPE r515_metrics_generated_unixtime gauge
r515_metrics_generated_unixtime ${NOW}
# HELP r515_storage_mounted Whether /mnt/storage is a real mounted filesystem.
# TYPE r515_storage_mounted gauge
r515_storage_mounted ${storage_mounted}
# HELP r515_storage_writable Whether a real write test to /mnt/storage succeeded.
# TYPE r515_storage_writable gauge
r515_storage_writable ${storage_writable}
# HELP r515_gluetun_healthy Whether the Gluetun Docker health status is healthy.
# TYPE r515_gluetun_healthy gauge
r515_gluetun_healthy ${gluetun_healthy}
# HELP r515_byparr_health Whether the real Byparr /health endpoint responds successfully.
# TYPE r515_byparr_health gauge
r515_byparr_health ${byparr_health}
# HELP r515_postboot_recovery_success Whether the post-boot recovery oneshot is active with exit status 0.
# TYPE r515_postboot_recovery_success gauge
r515_postboot_recovery_success ${postboot_success}
# HELP r515_byparr_recovery_success Whether the Byparr recovery oneshot is active with exit status 0.
# TYPE r515_byparr_recovery_success gauge
r515_byparr_recovery_success ${byparr_recovery_success}
# HELP r515_config_backup_present Whether at least one R515 config backup archive exists.
# TYPE r515_config_backup_present gauge
r515_config_backup_present ${backup_present}
# HELP r515_config_backup_age_seconds Age in seconds of the newest R515 config backup, or -1 when none exists.
# TYPE r515_config_backup_age_seconds gauge
r515_config_backup_age_seconds ${backup_age}
EOF

chmod 0644 "$TMP"
mv -f "$TMP" "$OUT"
trap - EXIT
COLLECTOR_SCRIPT

chmod 0755 "$COLLECTOR"
echo "PASS: installed $COLLECTOR"

section "INSTALL SYSTEMD TIMER"
cat > /etc/systemd/system/r515-custom-metrics.service <<EOF
[Unit]
Description=Generate R515 custom Prometheus metrics
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${COLLECTOR}
EOF

cat > /etc/systemd/system/r515-custom-metrics.timer <<'EOF'
[Unit]
Description=Refresh R515 custom Prometheus metrics every minute

[Timer]
OnBootSec=45s
OnUnitActiveSec=60s
AccuracySec=5s
Unit=r515-custom-metrics.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now r515-custom-metrics.timer

section "FIRST COLLECTION"
systemctl start r515-custom-metrics.service

if [ ! -s "$METRICS_FILE" ]; then
  echo "ERROR: custom metrics file was not created."
  systemctl status r515-custom-metrics.service --no-pager -l || true
  journalctl -u r515-custom-metrics.service -n 80 --no-pager || true
  exit 1
fi

cat "$METRICS_FILE"

section "VERIFY NODE_EXPORTER"
TMP_METRICS=$(mktemp)
trap 'rm -f "$TMP_METRICS"' EXIT
curl -fsS --max-time 10 -o "$TMP_METRICS" "http://${HOST_IP}:9100/metrics"

EXPECTED=(
  r515_metrics_collector_success
  r515_storage_mounted
  r515_storage_writable
  r515_gluetun_healthy
  r515_byparr_health
  r515_postboot_recovery_success
  r515_byparr_recovery_success
  r515_config_backup_present
  r515_config_backup_age_seconds
)

for metric in "${EXPECTED[@]}"; do
  grep -q "^${metric} " "$TMP_METRICS" || {
    echo "ERROR: node_exporter is not exposing ${metric}."
    exit 1
  }
done

echo "PASS: node_exporter exposes all R515 custom metrics."

section "VERIFY PROMETHEUS"
echo "Waiting for a Prometheus scrape..."
sleep 20

python3 - <<PY
import json
import urllib.parse
import urllib.request

base = 'http://${HOST_IP}:9090/api/v1/query?'
metrics = [
    'r515_storage_mounted',
    'r515_storage_writable',
    'r515_gluetun_healthy',
    'r515_byparr_health',
    'r515_postboot_recovery_success',
    'r515_byparr_recovery_success',
    'r515_config_backup_present',
    'r515_config_backup_age_seconds',
]

missing = []
print('Prometheus values:')
for metric in metrics:
    url = base + urllib.parse.urlencode({'query': metric})
    with urllib.request.urlopen(url, timeout=5) as response:
        payload = json.load(response)
    result = payload.get('data', {}).get('result', [])
    if not result:
        missing.append(metric)
        print(f'  {metric}: MISSING')
        continue
    value = result[0]['value'][1]
    print(f'  {metric}: {value}')

if missing:
    raise SystemExit('ERROR: missing Prometheus metrics: ' + ', '.join(missing))

print('PASS: Prometheus is ingesting the R515 custom metrics.')
PY

section "TIMER"
systemctl list-timers r515-custom-metrics.timer --no-pager

echo
echo "=== R515 CUSTOM METRICS INSTALL COMPLETE ==="
