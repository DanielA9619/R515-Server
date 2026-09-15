#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: run as root on the Proxmox host."
  exit 1
fi

command -v curl >/dev/null || {
  echo "ERROR: curl is required."
  exit 1
}

ENV_FILE="/etc/r515-healthchecks.env"
SCRIPT="/usr/local/sbin/r515-external-heartbeat.sh"
SERVICE="/etc/systemd/system/r515-external-heartbeat.service"
TIMER="/etc/systemd/system/r515-external-heartbeat.timer"

printf '\n=== R515 EXTERNAL DEAD-MAN HEARTBEAT ===\n\n'

if [ -s "$ENV_FILE" ]; then
  echo "INFO: existing heartbeat URL retained from $ENV_FILE"
else
  read -rsp "Paste the Healthchecks.io ping URL (hidden): " HC_URL
  echo

  case "$HC_URL" in
    https://*) ;;
    *)
      echo "ERROR: ping URL must use https://"
      exit 1
      ;;
  esac

  OLD_UMASK="$(umask)"
  umask 077
  printf 'HC_URL=%q\n' "$HC_URL" > "$ENV_FILE"
  chmod 0600 "$ENV_FILE"
  umask "$OLD_UMASK"
  unset HC_URL

  echo "PASS: heartbeat URL stored root-only in $ENV_FILE"
fi

cat > "$SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

source /etc/r515-healthchecks.env

[ -n "${HC_URL:-}" ] || {
  echo "ERROR: HC_URL is empty" >&2
  exit 1
}

curl \
  --fail \
  --silent \
  --show-error \
  --max-time 20 \
  --retry 2 \
  --retry-delay 3 \
  "$HC_URL" \
  >/dev/null
EOF
chmod 0700 "$SCRIPT"

cat > "$SERVICE" <<'EOF'
[Unit]
Description=R515 external dead-man heartbeat
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/r515-external-heartbeat.sh
User=root
EOF
chmod 0644 "$SERVICE"

cat > "$TIMER" <<'EOF'
[Unit]
Description=Send R515 external heartbeat every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=15s
Unit=r515-external-heartbeat.service

[Install]
WantedBy=timers.target
EOF
chmod 0644 "$TIMER"

systemctl daemon-reload
systemctl enable --now r515-external-heartbeat.timer >/dev/null

# Send one immediate ping so the external check can be validated now.
systemctl start r515-external-heartbeat.service

RESULT="$(systemctl show r515-external-heartbeat.service -p Result --value)"
if [ "$RESULT" != "success" ]; then
  echo "ERROR: immediate heartbeat failed (Result=$RESULT)."
  journalctl -u r515-external-heartbeat.service -n 30 --no-pager || true
  exit 1
fi

echo
systemctl list-timers r515-external-heartbeat.timer --no-pager

echo
echo "PASS: immediate external heartbeat succeeded."
echo "PASS: timer enabled for every 5 minutes."
echo "Ping URL remains private and was not printed."
echo
echo "=== EXTERNAL HEARTBEAT SETUP COMPLETE ==="
