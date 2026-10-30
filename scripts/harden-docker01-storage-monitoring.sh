#!/usr/bin/env bash
set -Eeuo pipefail

HOST_IP="192.168.10.135"
COLLECTOR="/usr/local/sbin/r515-custom-metrics.sh"
PROM_DIR="/srv/docker/monitoring/metrics"
PROM_RULES="${PROM_DIR}/prometheus/r515-alerts.yml"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${PROM_RULES}.pre-docker01-storage-hardening-${STAMP}"

section(){ printf '\n=== %s ===\n' "$1"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "Run as root on docker01."
command -v docker >/dev/null || fail "docker missing"
command -v curl >/dev/null || fail "curl missing"
[ -f "$COLLECTOR" ] || fail "Missing $COLLECTOR"
[ -f "$PROM_RULES" ] || fail "Missing $PROM_RULES"

section "HARDEN TEXTFILE COLLECTOR"

cp -a "$COLLECTOR" "${COLLECTOR}.pre-storage-hardening-${STAMP}"

python3 - "$COLLECTOR" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

if "set -u\n" in text and "set -euo pipefail\n" not in text:
    text = text.replace("set -u\n", "set -euo pipefail\n", 1)

needle = 'chmod 0644 "$TMP"\nmv -f "$TMP" "$OUT"'
guard = '''if [ ! -s "$TMP" ]; then
  echo "ERROR: refusing to replace $OUT with an empty metrics file." >&2
  exit 1
fi

chmod 0644 "$TMP"
mv -f "$TMP" "$OUT"'''

if "refusing to replace $OUT with an empty metrics file" not in text:
    if needle not in text:
        raise SystemExit("ERROR: expected collector publish block not found")
    text = text.replace(needle, guard, 1)

path.write_text(text)
PY

chmod 0755 "$COLLECTOR"
bash -n "$COLLECTOR"

systemctl start r515-custom-metrics.service
[ -s /var/lib/node_exporter/textfile/r515.prom ] || fail "r515.prom is empty after collection"
grep -q '^r515_metrics_collector_success 1$' /var/lib/node_exporter/textfile/r515.prom ||
  fail "collector success metric missing"
echo "PASS: collector now fails closed and preserves the last good metrics file."

section "VERIFY ROOT FILESYSTEM METRICS"

python3 - <<'PY'
import json
import urllib.parse
import urllib.request

base = "http://192.168.10.135:9090/api/v1/query?"
queries = {
    "size": 'node_filesystem_size_bytes{job="docker01",mountpoint="/"}',
    "avail": 'node_filesystem_avail_bytes{job="docker01",mountpoint="/"}',
}
for name, query in queries.items():
    url = base + urllib.parse.urlencode({"query": query})
    with urllib.request.urlopen(url, timeout=5) as response:
        result = json.load(response).get("data", {}).get("result", [])
    if not result:
        raise SystemExit(f"ERROR: Prometheus has no Docker01 root filesystem {name} metric")
    print(f"PASS: root filesystem {name} metric = {result[0]['value'][1]}")
PY

section "ADD DOCKER01 ROOT DISK ALERTS"

if grep -q 'alert: Docker01RootFilesystemHigh' "$PROM_RULES"; then
  echo "INFO: Docker01 root disk alerts already exist; not adding duplicates."
else
  cp -a "$PROM_RULES" "$BACKUP"

  cat >> "$PROM_RULES" <<'EOF'

  - name: r515-docker01-storage
    interval: 30s
    rules:
      - alert: Docker01RootFilesystemHigh
        expr: (100 * (1 - node_filesystem_avail_bytes{job="docker01",mountpoint="/"} / node_filesystem_size_bytes{job="docker01",mountpoint="/"}) > 80) and (100 * (1 - node_filesystem_avail_bytes{job="docker01",mountpoint="/"} / node_filesystem_size_bytes{job="docker01",mountpoint="/"}) <= 90)
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: Docker01 root filesystem is above 80 percent
          description: Docker01 root filesystem usage has remained between 80 and 90 percent for 15 minutes.

      - alert: Docker01RootFilesystemCritical
        expr: 100 * (1 - node_filesystem_avail_bytes{job="docker01",mountpoint="/"} / node_filesystem_size_bytes{job="docker01",mountpoint="/"}) > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: Docker01 root filesystem is above 90 percent
          description: Docker01 root filesystem usage has remained above 90 percent for 5 minutes. Free space before services and textfile metrics fail.
EOF
fi

section "VALIDATE FULL PROMETHEUS CONFIG"

docker run --rm \
  --entrypoint /bin/promtool \
  -v "${PROM_DIR}/prometheus:/etc/prometheus:ro" \
  prom/prometheus:v3.13.3 \
  check config /etc/prometheus/prometheus.yml

section "RELOAD PROMETHEUS"

docker kill --signal=HUP prometheus >/dev/null
sleep 5
curl -fsS --max-time 5 "http://${HOST_IP}:9090/-/ready" >/dev/null

RULES_JSON="$(mktemp)"
trap 'rm -f "$RULES_JSON"' EXIT
curl -fsS --max-time 5 -o "$RULES_JSON" "http://${HOST_IP}:9090/api/v1/rules"

grep -q '"name":"Docker01RootFilesystemHigh"' "$RULES_JSON" ||
  fail "warning rule did not load"
grep -q '"name":"Docker01RootFilesystemCritical"' "$RULES_JSON" ||
  fail "critical rule did not load"

section "CURRENT ROOT USE"

python3 - <<'PY'
import json
import urllib.parse
import urllib.request
q='100 * (1 - node_filesystem_avail_bytes{job="docker01",mountpoint="/"} / node_filesystem_size_bytes{job="docker01",mountpoint="/"})'
url='http://192.168.10.135:9090/api/v1/query?' + urllib.parse.urlencode({'query': q})
with urllib.request.urlopen(url,timeout=5) as r:
    rows=json.load(r).get('data',{}).get('result',[])
if not rows:
    raise SystemExit("ERROR: no current root usage result")
print(f"Docker01 root usage: {float(rows[0]['value'][1]):.1f}%")
PY

echo
echo "=== DOCKER01 STORAGE MONITORING HARDENED ==="
