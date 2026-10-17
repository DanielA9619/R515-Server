#!/usr/bin/env bash
set -Eeuo pipefail

SECRET_FILE="/etc/r515-mullvad-expiry.env"
CHECKER="/usr/local/sbin/r515-mullvad-expiry-check.py"
STATE_DIR="/var/lib/r515-mullvad-expiry"
TEXTFILE_DIR="/var/lib/node_exporter/textfile"
SERVICE="/etc/systemd/system/r515-mullvad-expiry.service"
TIMER="/etc/systemd/system/r515-mullvad-expiry.timer"
TOPIC_FILE="/srv/docker/monitoring/alerting/ntfy-topic.txt"

pass(){ echo "PASS: $*"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }
section(){ printf '\n=== %s ===\n' "$1"; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "Run this as root on docker01."
command -v pveversion >/dev/null 2>&1 && fail "Run this on docker01, not the Proxmox host."
command -v python3 >/dev/null 2>&1 || fail "python3 is required."
command -v systemctl >/dev/null 2>&1 || fail "systemctl is required."
[ -s "$TOPIC_FILE" ] || fail "R515 Alerts ntfy topic file is missing: $TOPIC_FILE"

section "MULLVAD ACCOUNT SECRET"

if [ -s "$SECRET_FILE" ]; then
    chmod 0600 "$SECRET_FILE"
    echo "Existing Mullvad account secret retained."
else
    read -rsp "Mullvad account number (input hidden): " ACCOUNT_NUMBER
    echo

    [[ "$ACCOUNT_NUMBER" =~ ^[0-9]{16}$ ]] || fail "Expected a 16-digit Mullvad account number."

    umask 077
    printf 'MULLVAD_ACCOUNT_NUMBER=%s\n' "$ACCOUNT_NUMBER" > "$SECRET_FILE"
    chmod 0600 "$SECRET_FILE"
    unset ACCOUNT_NUMBER
    pass "Mullvad account number stored root-only at $SECRET_FILE"
fi

section "INSTALL CHECKER"

mkdir -p "$STATE_DIR" "$TEXTFILE_DIR"
chmod 0700 "$STATE_DIR"
chmod 0755 /var/lib/node_exporter "$TEXTFILE_DIR" 2>/dev/null || true

cat > "$CHECKER" <<'PY'
#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

SECRET_FILE = Path("/etc/r515-mullvad-expiry.env")
TOPIC_FILE = Path("/srv/docker/monitoring/alerting/ntfy-topic.txt")
STATE_DIR = Path("/var/lib/r515-mullvad-expiry")
STATE_FILE = STATE_DIR / "state.json"
METRIC_FILE = Path("/var/lib/node_exporter/textfile/r515-mullvad.prom")

API_BASE = "https://api.mullvad.net"
USER_AGENT = "r515-mullvad-expiry-monitor/1.0"

WARN_SECONDS = 3 * 24 * 60 * 60
CRIT_SECONDS = 24 * 60 * 60

def read_account_number():
    raw = SECRET_FILE.read_text().strip()
    if not raw.startswith("MULLVAD_ACCOUNT_NUMBER="):
        raise RuntimeError("invalid Mullvad secret file format")
    account = raw.split("=", 1)[1].strip()
    if len(account) != 16 or not account.isdigit():
        raise RuntimeError("invalid Mullvad account number in secret file")
    return account

def request_json(path, *, method="GET", body=None, token=None):
    headers = {
        "Accept": "application/json",
        "User-Agent": USER_AGENT,
    }
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode("utf-8")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = urllib.request.Request(
        API_BASE + path,
        data=data,
        headers=headers,
        method=method,
    )
    with urllib.request.urlopen(req, timeout=15) as response:
        return json.load(response)

def fetch_expiry(account_number):
    token_data = request_json(
        "/auth/v1/token",
        method="POST",
        body={"account_number": account_number},
    )
    token = token_data.get("access_token")
    if not token:
        raise RuntimeError("Mullvad API did not return an access token")

    account_data = request_json(
        "/accounts/v1/accounts/me",
        token=token,
    )
    expiry_raw = account_data.get("expiry")
    if not expiry_raw:
        raise RuntimeError("Mullvad API did not return an account expiry")

    expiry = datetime.fromisoformat(expiry_raw.replace("Z", "+00:00"))
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    return expiry.astimezone(timezone.utc)

def bucket_for(seconds_remaining):
    if seconds_remaining <= 0:
        return "expired"
    if seconds_remaining <= CRIT_SECONDS:
        return "critical"
    if seconds_remaining <= WARN_SECONDS:
        return "warning"
    return "healthy"

def human_remaining(seconds):
    if seconds <= 0:
        return "expired"
    hours = max(1, int((seconds + 3599) // 3600))
    days, rem_hours = divmod(hours, 24)
    if days:
        return f"{days}d {rem_hours}h"
    return f"{hours}h"

def load_state():
    try:
        return json.loads(STATE_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

def save_state(state):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=2) + "\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, STATE_FILE)

def write_metrics(expiry, seconds_remaining, success=1):
    METRIC_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = METRIC_FILE.with_suffix(".tmp")
    text = (
        "# HELP r515_mullvad_check_success Whether the latest Mullvad account-time check succeeded.\n"
        "# TYPE r515_mullvad_check_success gauge\n"
        f"r515_mullvad_check_success {success}\n"
        "# HELP r515_mullvad_expiry_unixtime Mullvad account expiry as a Unix timestamp.\n"
        "# TYPE r515_mullvad_expiry_unixtime gauge\n"
        f"r515_mullvad_expiry_unixtime {int(expiry.timestamp())}\n"
        "# HELP r515_mullvad_seconds_remaining Seconds of Mullvad account credit remaining.\n"
        "# TYPE r515_mullvad_seconds_remaining gauge\n"
        f"r515_mullvad_seconds_remaining {max(0, int(seconds_remaining))}\n"
    )
    tmp.write_text(text)
    os.chmod(tmp, 0o644)
    os.replace(tmp, METRIC_FILE)

def send_ntfy(title, message, *, priority=3, tags=None):
    topic = TOPIC_FILE.read_text().strip()
    if not topic:
        raise RuntimeError("R515 Alerts ntfy topic is empty")

    payload = {
        "topic": topic,
        "title": title,
        "message": message,
        "priority": priority,
    }
    if tags:
        payload["tags"] = tags

    req = urllib.request.Request(
        "https://ntfy.sh",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": USER_AGENT,
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as response:
        if response.status < 200 or response.status >= 300:
            raise RuntimeError(f"ntfy returned HTTP {response.status}")

def transition_notification(old_bucket, new_bucket, expiry, seconds_remaining):
    remaining = human_remaining(seconds_remaining)
    expiry_local = expiry.astimezone().strftime("%a %b %d at %I:%M %p %Z")

    if new_bucket == "warning":
        return (
            "Mullvad Time Running Low",
            f"About {remaining} of VPN time remains. Account time expires {expiry_local}.",
            3,
            ["warning"],
        )
    if new_bucket == "critical":
        return (
            "Mullvad Expires Within 24 Hours",
            f"Only about {remaining} of VPN time remains. Add time before {expiry_local} to keep qBittorrent online.",
            4,
            ["warning", "hourglass_flowing_sand"],
        )
    if new_bucket == "expired":
        return (
            "Mullvad Time Expired",
            "The Mullvad account is out of time. Gluetun/qBittorrent VPN connectivity will fail until time is added.",
            5,
            ["rotating_light"],
        )
    if new_bucket == "healthy" and old_bucket in {"warning", "critical", "expired"}:
        return (
            "Mullvad Time Restored",
            f"Mullvad account time is healthy again ({remaining} remaining; expires {expiry_local}).",
            2,
            ["white_check_mark"],
        )
    return None

def main():
    account = read_account_number()
    expiry = fetch_expiry(account)
    now = datetime.now(timezone.utc)
    seconds_remaining = (expiry - now).total_seconds()
    bucket = bucket_for(seconds_remaining)

    write_metrics(expiry, seconds_remaining, success=1)

    state = load_state()
    old_bucket = state.get("bucket")

    notification = transition_notification(old_bucket, bucket, expiry, seconds_remaining)
    if notification is not None:
        title, message, priority, tags = notification
        send_ntfy(title, message, priority=priority, tags=tags)

    save_state(
        {
            "bucket": bucket,
            "expiry": expiry.isoformat(),
            "last_success": now.isoformat(),
        }
    )

    print(f"Mullvad status: {bucket}")
    print(f"Time remaining: {human_remaining(seconds_remaining)}")
    print(f"Expires: {expiry.astimezone().strftime('%Y-%m-%d %H:%M:%S %Z')}")

if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as exc:
        print(f"ERROR: Mullvad/ntfy HTTP error {exc.code}", file=sys.stderr)
        raise SystemExit(1)
    except urllib.error.URLError as exc:
        print(f"ERROR: network error: {exc.reason}", file=sys.stderr)
        raise SystemExit(1)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
PY

chmod 0755 "$CHECKER"
python3 -m py_compile "$CHECKER"
pass "Checker installed and Python syntax validated."

section "INSTALL SYSTEMD TIMER"

cat > "$SERVICE" <<EOF
[Unit]
Description=Check Mullvad account credit and notify before expiry
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$CHECKER
NoNewPrivileges=true
PrivateTmp=true
EOF

cat > "$TIMER" <<'EOF'
[Unit]
Description=Check Mullvad account credit every 6 hours

[Timer]
OnBootSec=5min
OnUnitActiveSec=6h
Persistent=true
AccuracySec=5min
Unit=r515-mullvad-expiry.service

[Install]
WantedBy=timers.target
EOF

chmod 0644 "$SERVICE" "$TIMER"
systemctl daemon-reload
systemctl enable --now r515-mullvad-expiry.timer

section "FIRST ACCOUNT CHECK"

if ! systemctl start r515-mullvad-expiry.service; then
    systemctl status r515-mullvad-expiry.service --no-pager -l || true
    journalctl -u r515-mullvad-expiry.service -n 80 --no-pager || true
    fail "Initial Mullvad account check failed."
fi

pass "Initial Mullvad account check succeeded."

section "FINAL STATUS"

systemctl list-timers r515-mullvad-expiry.timer --all --no-pager

echo
journalctl -u r515-mullvad-expiry.service -n 20 --no-pager

echo
echo "Alerts:"
echo "  - once when remaining time drops below 3 days"
echo "  - once when remaining time drops below 24 hours"
echo "  - once when the account actually expires"
echo "  - one recovery notification after time is added"
echo "  - checks every 6 hours"
echo "  - account number remains root-only and is never printed"
echo
echo "=== MULLVAD EXPIRY MONITOR INSTALLED ==="
