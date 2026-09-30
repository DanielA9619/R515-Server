#!/usr/bin/env bash
set -Eeuo pipefail

BACKUP_SCRIPT="/srv/docker/scripts/backup-r515-configs.sh"
BACKUP_ROOT="/mnt/storage/backups"
RUNNER="/usr/local/sbin/r515-config-backup-runner.sh"
SERVICE="/etc/systemd/system/r515-config-backup.service"
TIMER="/etc/systemd/system/r515-config-backup.timer"
CALENDAR="*-*-* 03:30:00 America/Denver"

pass(){ echo "PASS: $*"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }
section(){ printf '\n=== %s ===\n' "$1"; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "Run as root on docker01."
command -v pveversion >/dev/null 2>&1 && fail "Run this on docker01, not the Proxmox host."
for cmd in systemctl systemd-analyze findmnt flock gzip tar; do
  command -v "$cmd" >/dev/null || fail "$cmd not found."
done
[ -f "$BACKUP_SCRIPT" ] || fail "Backup script not found: $BACKUP_SCRIPT"
[ -d "$BACKUP_ROOT" ] || fail "Backup root not found: $BACKUP_ROOT"

section "PREFLIGHT"
findmnt -T /mnt/storage >/dev/null || fail "/mnt/storage is not mounted."
[ -w "$BACKUP_ROOT" ] || fail "$BACKUP_ROOT is not writable."
systemd-analyze calendar "$CALENDAR" >/dev/null || fail "Timer calendar expression is invalid."
pass "Existing backup script found."
pass "/mnt/storage is mounted and backup directory is writable."
pass "Nightly schedule validates: 03:30 America/Denver."

section "INSTALL VALIDATING BACKUP RUNNER"

cat > "$RUNNER" <<'RUNNER'
#!/usr/bin/env bash
set -Eeuo pipefail

BACKUP_SCRIPT="/srv/docker/scripts/backup-r515-configs.sh"
BACKUP_ROOT="/mnt/storage/backups"

MARKER="$(mktemp /run/r515-backup-marker.XXXXXX)"
LOG="$(mktemp /run/r515-backup-log.XXXXXX)"
trap 'rm -f "$MARKER" "$LOG"' EXIT

# Marker exists before the backup starts, allowing us to identify
# the archive created by this run without depending on a filename timestamp.
touch "$MARKER"

set +e
/usr/bin/bash "$BACKUP_SCRIPT" 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
set -e

ARCHIVE="$(
  find "$BACKUP_ROOT" -type f -name 'r515-configs-*.tar.gz' -newer "$MARKER" \
    -printf '%T@ %p\n' 2>/dev/null |
  sort -nr |
  head -n 1 |
  cut -d' ' -f2-
)"

[ -n "$ARCHIVE" ] || {
  echo "ERROR: backup script did not create a new r515-configs archive." >&2
  exit 1
}

gzip -t "$ARCHIVE" || {
  echo "ERROR: gzip integrity check failed: $ARCHIVE" >&2
  exit 1
}

tar -tzf "$ARCHIVE" >/dev/null || {
  echo "ERROR: tar archive validation failed: $ARCHIVE" >&2
  exit 1
}

if [ "$rc" -eq 0 ]; then
  echo "PASS: backup completed and archive validates: $ARCHIVE"
  exit 0
fi

if [ "$rc" -eq 1 ]; then
  TAR_WARNINGS="$(grep '^tar:' "$LOG" || true)"

  DISALLOWED="$(
    printf '%s\n' "$TAR_WARNINGS" |
    grep -vE '(: file changed as we read it$|: socket ignored$|^tar: Exiting with failure status due to previous errors$)' ||
    true
  )"

  if [ -n "$TAR_WARNINGS" ] && [ -z "$DISALLOWED" ]; then
    echo "WARNING: tar reported only expected live-file/socket warnings."
    echo "PASS: archive itself validates, so this run is accepted: $ARCHIVE"
    exit 0
  fi
fi

echo "ERROR: backup script exited with status $rc." >&2
echo "ERROR: archive exists and validates, but the failure was not limited to known live-file warnings." >&2
exit "$rc"
RUNNER

chmod 0755 "$RUNNER"

section "INSTALL SYSTEMD SERVICE"

cat > "$SERVICE" <<EOF
[Unit]
Description=R515 automatic configuration backup
Wants=network-online.target
After=network-online.target docker.service
RequiresMountsFor=/mnt/storage

[Service]
Type=oneshot
ExecStart=/usr/bin/flock -n /run/lock/r515-config-backup.lock $RUNNER
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
systemctl reset-failed r515-config-backup.service 2>/dev/null || true
systemctl enable --now r515-config-backup.timer
pass "Backup service, validating runner, and timer installed."
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

find "$BACKUP_ROOT" -maxdepth 3 -type f -name 'r515-configs-*.tar.gz' \
  -printf '%T@ %TY-%Tm-%Td %TH:%TM %10s %p\n' 2>/dev/null |
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
echo "Live data note:"
echo "  The current legacy backup script still archives live application data."
echo "  This runner accepts only the known tar warnings after validating the archive."
echo "  Database-consistent backups remain a separate hardening task."
echo
echo "Retention:"
echo "  No automatic deletion is enabled yet."
echo "  /mnt/storage/backups contains multiple backup types, so retention"
echo "  should be added only after confirming the exact config-backup naming."
echo
echo "=== AUTOMATIC CONFIG BACKUPS COMPLETE ==="
