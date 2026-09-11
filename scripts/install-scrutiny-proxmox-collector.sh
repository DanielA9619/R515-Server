#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "This script must run as root."
  echo "Use: sudo bash $0"
  exit 1
fi

VERSION="v0.9.3"
ARCH="amd64"
BINARY="scrutiny-collector-metrics-linux-${ARCH}"
URL="https://github.com/AnalogJ/scrutiny/releases/download/${VERSION}/${BINARY}"
SHA256="7be2294470a087083bab66c1fea8e1b4c278920b5c46ab80ed2c0cc8c4c0a2c3"
INSTALL_DIR="/opt/scrutiny/bin"
INSTALL_PATH="${INSTALL_DIR}/scrutiny-collector-metrics"
API_ENDPOINT="http://192.168.10.135:8082"
HOST_ID="r515-proxmox"

case "$(uname -m)" in
  x86_64|amd64) ;;
  *)
    echo "ERROR: this installer is pinned for linux-amd64; detected $(uname -m)."
    exit 1
    ;;
esac

if ! command -v smartctl >/dev/null 2>&1; then
  echo "ERROR: smartctl is not installed."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is not installed."
  exit 1
fi

echo "Detected SMART devices:"
smartctl --scan-open || true

echo
echo "Checking Scrutiny hub..."
if ! curl -fsS --max-time 5 "${API_ENDPOINT}/api/health" >/dev/null; then
  echo "ERROR: Scrutiny hub is not reachable at ${API_ENDPOINT}."
  echo "Install/start the docker01 Scrutiny hub first."
  exit 1
fi

mkdir -p "${INSTALL_DIR}"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

curl -fL "${URL}" -o "${TMP}"
echo "${SHA256}  ${TMP}" | sha256sum -c -
install -m 0755 "${TMP}" "${INSTALL_PATH}"

cat > /etc/systemd/system/scrutiny-collector.service <<EOF
[Unit]
Description=Scrutiny SMART metrics collector for R515 Proxmox
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${INSTALL_PATH} run --api-endpoint ${API_ENDPOINT} --host-id ${HOST_ID}
EOF

cat > /etc/systemd/system/scrutiny-collector.timer <<'EOF'
[Unit]
Description=Run Scrutiny SMART collector every 30 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=30min
AccuracySec=1min
Persistent=true
Unit=scrutiny-collector.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now scrutiny-collector.timer

echo
echo "Running initial SMART collection now..."
systemctl start scrutiny-collector.service

if systemctl is-failed --quiet scrutiny-collector.service; then
  echo "ERROR: initial Scrutiny collection failed."
  systemctl status scrutiny-collector.service --no-pager -l || true
  journalctl -u scrutiny-collector.service -n 120 --no-pager || true
  exit 1
fi

echo
echo "PASS: Scrutiny collector installed and initial collection completed."
systemctl status scrutiny-collector.service --no-pager -l || true
systemctl list-timers scrutiny-collector.timer --no-pager || true
echo
echo "Scrutiny UI: ${API_ENDPOINT}"
