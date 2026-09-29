#!/usr/bin/env bash
set -Eeuo pipefail

BACKUP_SCRIPT="/srv/docker/scripts/backup-r515-configs.sh"
BACKUP_ROOT="/mnt/storage/backups"
SERVICE="/etc/systemd/system/r515-config-backup.service"
TIMER="/etc/systemd/system/r515-config-backup.timer"
CALENDAR="*-*-* 03:30:00 America/Denver"

pass(){ echo "PASS: $*"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }
section(){ printf '\n=== %s ===\n' "$1"; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "Run as root on docker01."
command -v pveversion >/dev/null 2>&1 && fail "Run this on docker01, not the Proxmox host."
command -v systemctl >/dev/null || fail "systemd not found."
command -v systemd-analyze >/dev/null || fail "systemd-analyze not found."
command -v findmnt >/dev/null || fail "findmnt not found."
command -v flock >/dev/null || fail "flock not found."
[ -f "$BACKUP_SCRIPT" ] || fail "Backup script not found: $BACKUP_SCRIPT"
[ -d "$BACKUP_ROOT" ] || fail "Backup root not found: $BACKUP_ROOT"

section "PREFLIGHT"

findmnt -T /mnt/storage >/dev/null || fail "/mnt/storage is not mounted."
[ -w "$BACKUP_ROOT" ] || fail "$BACKUP_ROOT is not writable."
systemd-analyze calendar "$CALENDAR" >/dev/null || fail "Timer calendar expression is invalid."

pass "Existing backup script found."
pass "/mnt/storage is mounted and backup directory is writable."
pass "Nightly schedule validates: 03:30 America/Denver."

section "INSTALL SYSTEMD SERVICE"

cat > "$SERVICE" <<EOF
[Unit]
Description=R515 automatic configuration backup
Wants=network-online.target
After=network-online.target docker.service
RequiresMountsFor=/mnt/storage

[Service]
Type=oneshot
ExecStart=/usr/bin/flock -n /run/lock/r515-config-backup.lock /usr/bin/bash $BACKUP_SCRIPT
TimeoutStartSec=2h
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
EOF

cat > "$TIMER" <<EOF
[Unit]
Description=Nightly R515 configuration backup

[Timer]
OnCalendar=$CALENDAR
Persistent=true
AccuracySec=1min
Unit=r515-config-backup.service

[Install]
WantedBy=timers.target
EOF

chmod 0644 "$SERVICE" "$TIMER"

systemctl daemon-reload
systemctl enable --now r515-config-backup.timer

pass "Backup service and timer installed."
pass "Persistent timer enabled."

section "RUN TEST BACKUP"

if ! systemctl start r515-config-backup.service; then
  echo
  systemctl status r515-config-backup.service --no-pager -l || true
  echo
  journalctl -u r515-config-backup.service -n 100 --no-pager || true
  fail "Test backup failed."
fi

systemctl is-failed --quiet r515-config-backup.service &&
  fail "Backup service entered failed state."

pass "Test backup completed successfully."

section "RECENT BACKUP OUTPUT"

find "$BACKUP_ROOT" -maxdepth 3 -type f -printf '%T@ %TY-%Tm-%Td %TH:%TM %10s %p\n' 2>/dev/null |
  sort -nr |
  head -n 10 |
  cut -d' ' -f2- || true

section "TIMER STATUS"

systemctl status r515-config-backup.timer --no-pager -l
echo
systemctl list-timers r515-config-backup.timer --all --no-pager

echo
echo "Logs:"
echo "  journalctl -u r515-config-backup.service"
echo
echo "Manual run:"
echo "  systemctl start r515-config-backup.service"
echo
echo "Schedule:"
echo "  Every day at 03:30 America/Denver"
echo "  Persistent=true, so a missed run executes after the server returns."
echo
echo "Retention:"
echo "  No automatic deletion is enabled yet."
echo "  /mnt/storage/backups contains multiple backup types, so retention"
echo "  should be added only after confirming the exact config-backup naming."
echo
echo "=== AUTOMATIC CONFIG BACKUPS COMPLETE ==="
