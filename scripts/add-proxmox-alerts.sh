#!/usr/bin/env bash
set -euo pipefail

[ "${EUID:-$(id -u)}" -eq 0 ] || {
  echo "ERROR: run as root on docker01."
  exit 1
}

HOST_IP="192.168.10.135"
PROM_DIR="/srv/docker/monitoring/metrics"
PROM_RULES="${PROM_DIR}/prometheus/r515-alerts.yml"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${PROM_RULES}.pre-proxmox-alerts-${STAMP}"

section() {
  printf '\n=== %s ===\n' "$1"
}

section "R515 PROXMOX ALERTS"

[ -f "$PROM_RULES" ] || {
  echo "ERROR: missing $PROM_RULES"
  exit 1
}

curl -fsS --max-time 5 "http://${HOST_IP}:9090/-/ready" >/dev/null || {
  echo "ERROR: Prometheus is not ready."
  exit 1
}

curl -fsS --max-time 5 "http://${HOST_IP}:9093/-/ready" >/dev/null || {
  echo "ERROR: Alertmanager is not ready."
  exit 1
}

section "PRECHECK LIVE PROXMOX METRICS"
python3 - <<'PY'
import json
import urllib.parse
import urllib.request

base='http://192.168.10.135:9090/api/v1/query?'
checks={
  'Proxmox scrape':'up{job="proxmox"}',
  'R515 node':'pve_up{id="node/r515"}',
  'Docker01':'pve_up{id="qemu/100"}',
  'HAOS':'pve_up{id="qemu/101"}',
  'bulk status':'pve_up{id="storage/r515/bulk"}',
  'local status':'pve_up{id="storage/r515/local"}',
  'local-lvm status':'pve_up{id="storage/r515/local-lvm"}',
  'bulk size':'pve_disk_size_bytes{id="storage/r515/bulk"}',
  'bulk used':'pve_disk_usage_bytes{id="storage/r515/bulk"}',
  'local size':'pve_disk_size_bytes{id="storage/r515/local"}',
  'local used':'pve_disk_usage_bytes{id="storage/r515/local"}',
  'local-lvm size':'pve_disk_size_bytes{id="storage/r515/local-lvm"}',
  'local-lvm used':'pve_disk_usage_bytes{id="storage/r515/local-lvm"}',
}
missing=[]
for name,q in checks.items():
    url=base+urllib.parse.urlencode({'query':q})
    with urllib.request.urlopen(url,timeout=5) as r:
        data=json.load(r)
    rows=data.get('data',{}).get('result',[])
    if not rows:
        print(f'MISSING: {name}')
        missing.append(name)
    else:
        print(f'PASS: {name} = {rows[0]["value"][1]}')
if missing:
    raise SystemExit('ERROR: missing metrics: '+', '.join(missing))
PY

section "PATCH RULE FILE"

if grep -q '^  - name: r515-proxmox$' "$PROM_RULES"; then
  echo "INFO: r515-proxmox alert group already exists; no duplicate added."
else
  cp -a "$PROM_RULES" "$BACKUP"

  cat >> "$PROM_RULES" <<'EOF'

  - name: r515-proxmox
    interval: 30s
    rules:
      - alert: ProxmoxExporterOrAPIDown
        expr: up{job="proxmox"} == 0
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: Proxmox exporter/API scrape is down
          description: Prometheus cannot complete the Proxmox scrape through pve-exporter for 3 minutes.

      - alert: R515NodeReportedDown
        expr: pve_up{id="node/r515"} == 0
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: Proxmox reports the R515 node down
          description: Best-effort internal alert. A total R515 host outage also stops this Prometheus instance, so an external monitor is required for guaranteed host-down notification.

      - alert: Docker01VMReportedDown
        expr: pve_up{id="qemu/100"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: Proxmox reports Docker01 stopped
          description: Best-effort internal alert. Because Prometheus runs inside Docker01, a hard VM outage cannot reliably notify from this stack itself.

      - alert: HomeAssistantVMDown
        expr: pve_up{id="qemu/101"} == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: Home Assistant VM is down
          description: Proxmox has reported VM 101 (haos) stopped for at least 5 minutes.

      - alert: ProxmoxBulkStorageDown
        expr: pve_up{id="storage/r515/bulk"} == 0
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: Proxmox bulk storage is unavailable
          description: Proxmox has reported storage/r515/bulk unavailable for at least 3 minutes.

      - alert: ProxmoxLocalStorageDown
        expr: pve_up{id="storage/r515/local"} == 0
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: Proxmox local storage is unavailable
          description: Proxmox has reported storage/r515/local unavailable for at least 3 minutes.

      - alert: ProxmoxLocalLVMStorageDown
        expr: pve_up{id="storage/r515/local-lvm"} == 0
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: Proxmox local-lvm storage is unavailable
          description: Proxmox has reported storage/r515/local-lvm unavailable for at least 3 minutes.

      - alert: ProxmoxBulkStorageHigh
        expr: (100 * pve_disk_usage_bytes{id="storage/r515/bulk"} / pve_disk_size_bytes{id="storage/r515/bulk"} > 85) and (100 * pve_disk_usage_bytes{id="storage/r515/bulk"} / pve_disk_size_bytes{id="storage/r515/bulk"} <= 95)
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: Proxmox bulk storage is above 85 percent
          description: Proxmox bulk storage utilization has remained between 85 and 95 percent for 30 minutes.

      - alert: ProxmoxBulkStorageCritical
        expr: 100 * pve_disk_usage_bytes{id="storage/r515/bulk"} / pve_disk_size_bytes{id="storage/r515/bulk"} > 95
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: Proxmox bulk storage is above 95 percent
          description: Proxmox bulk storage utilization has remained above 95 percent for 15 minutes.

      - alert: ProxmoxLocalStorageHigh
        expr: (100 * pve_disk_usage_bytes{id="storage/r515/local"} / pve_disk_size_bytes{id="storage/r515/local"} > 85) and (100 * pve_disk_usage_bytes{id="storage/r515/local"} / pve_disk_size_bytes{id="storage/r515/local"} <= 95)
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: Proxmox local storage is above 85 percent
          description: Proxmox local storage utilization has remained between 85 and 95 percent for 30 minutes.

      - alert: ProxmoxLocalStorageCritical
        expr: 100 * pve_disk_usage_bytes{id="storage/r515/local"} / pve_disk_size_bytes{id="storage/r515/local"} > 95
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: Proxmox local storage is above 95 percent
          description: Proxmox local storage utilization has remained above 95 percent for 15 minutes.

      - alert: ProxmoxLocalLVMStorageHigh
        expr: (100 * pve_disk_usage_bytes{id="storage/r515/local-lvm"} / pve_disk_size_bytes{id="storage/r515/local-lvm"} > 85) and (100 * pve_disk_usage_bytes{id="storage/r515/local-lvm"} / pve_disk_size_bytes{id="storage/r515/local-lvm"} <= 95)
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: Proxmox local-lvm storage is above 85 percent
          description: Proxmox local-lvm storage utilization has remained between 85 and 95 percent for 30 minutes.

      - alert: ProxmoxLocalLVMStorageCritical
        expr: 100 * pve_disk_usage_bytes{id="storage/r515/local-lvm"} / pve_disk_size_bytes{id="storage/r515/local-lvm"} > 95
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: Proxmox local-lvm storage is above 95 percent
          description: Proxmox local-lvm storage utilization has remained above 95 percent for 15 minutes.
EOF

  echo "PASS: Proxmox alert group added."
fi

section "VALIDATE"

docker run --rm \
  --entrypoint /bin/promtool \
  -v "${PROM_DIR}/prometheus:/etc/prometheus:ro" \
  prom/prometheus:v3.13.3 \
  check config /etc/prometheus/prometheus.yml

echo "PASS: Prometheus config and rules are valid."

section "RELOAD PROMETHEUS"
docker kill --signal=HUP prometheus >/dev/null
sleep 5
curl -fsS --max-time 5 "http://${HOST_IP}:9090/-/ready" >/dev/null
echo "PASS: Prometheus reloaded without recreation."

section "VERIFY RULES LOADED"
RULES_JSON="$(mktemp)"
trap 'rm -f "$RULES_JSON"' EXIT
curl -fsS --max-time 5 -o "$RULES_JSON" "http://${HOST_IP}:9090/api/v1/rules"

for alert in \
  ProxmoxExporterOrAPIDown \
  R515NodeReportedDown \
  Docker01VMReportedDown \
  HomeAssistantVMDown \
  ProxmoxBulkStorageDown \
  ProxmoxLocalStorageDown \
  ProxmoxLocalLVMStorageDown \
  ProxmoxBulkStorageHigh \
  ProxmoxBulkStorageCritical \
  ProxmoxLocalStorageHigh \
  ProxmoxLocalStorageCritical \
  ProxmoxLocalLVMStorageHigh \
  ProxmoxLocalLVMStorageCritical
 do
  grep -q "\"name\":\"${alert}\"" "$RULES_JSON" || {
    echo "ERROR: rule not loaded: $alert"
    exit 1
  }
 done

echo "PASS: all Proxmox alert rules loaded."

section "CURRENT ALERT CONDITIONS"
python3 - <<'PY'
import json
import urllib.parse
import urllib.request

base='http://192.168.10.135:9090/api/v1/query?'
queries={
  'Proxmox scrape down':'up{job="proxmox"} == bool 0',
  'R515 node down':'pve_up{id="node/r515"} == bool 0',
  'Docker01 down':'pve_up{id="qemu/100"} == bool 0',
  'HAOS down':'pve_up{id="qemu/101"} == bool 0',
  'bulk unavailable':'pve_up{id="storage/r515/bulk"} == bool 0',
  'local unavailable':'pve_up{id="storage/r515/local"} == bool 0',
  'local-lvm unavailable':'pve_up{id="storage/r515/local-lvm"} == bool 0',
  'bulk >85%':'100*pve_disk_usage_bytes{id="storage/r515/bulk"}/pve_disk_size_bytes{id="storage/r515/bulk"} > bool 85',
  'local >85%':'100*pve_disk_usage_bytes{id="storage/r515/local"}/pve_disk_size_bytes{id="storage/r515/local"} > bool 85',
  'local-lvm >85%':'100*pve_disk_usage_bytes{id="storage/r515/local-lvm"}/pve_disk_size_bytes{id="storage/r515/local-lvm"} > bool 85',
}
for name,q in queries.items():
    url=base+urllib.parse.urlencode({'query':q})
    with urllib.request.urlopen(url,timeout=5) as r:
        data=json.load(r)
    rows=data.get('data',{}).get('result',[])
    value=rows[0]['value'][1] if rows else 'NO DATA'
    print(f'{name}: {value}')
PY

echo
echo "=== PROXMOX ALERTS COMPLETE ==="
echo "No test outage was induced."
echo "Current healthy conditions should all show 0 above."
