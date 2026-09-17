#!/usr/bin/env bash
set -Eeuo pipefail

HOST_IP="192.168.10.135"
BRIDGE_PORT="8787"

ALERT_DIR="/srv/docker/monitoring/alerting"
ALERT_TOPIC_FILE="${ALERT_DIR}/ntfy-topic.txt"
ALERT_CONFIG="${ALERT_DIR}/alertmanager.yml"

MEDIA_DIR="/srv/docker/monitoring/media-notifications"
MEDIA_TOPIC_FILE="${MEDIA_DIR}/ntfy-topic.txt"

BRIDGE_DIR="/srv/docker/monitoring/notification-bridge"
BRIDGE_PY="${BRIDGE_DIR}/bridge.py"
BRIDGE_COMPOSE="${BRIDGE_DIR}/docker-compose.yml"

STAMP="$(date +%Y%m%d-%H%M%S)"

section() { printf '\n=== %s ===\n' "$1"; }
pass() { echo "PASS: $*"; }
warn() { echo "WARNING: $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

cleanup() {
  rm -f /tmp/r515-alert-test.json 2>/dev/null || true
}
trap cleanup EXIT

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  fail "run this as root on docker01"
fi

section "R515 NOTIFICATION SETUP"

if command -v pveversion >/dev/null 2>&1; then
  fail "this script belongs on docker01, not the Proxmox host"
fi

command -v docker >/dev/null || fail "docker is not installed"
command -v curl >/dev/null || fail "curl is not installed"
command -v openssl >/dev/null || fail "openssl is not installed"
command -v python3 >/dev/null || fail "python3 is not installed"
command -v ss >/dev/null || fail "ss is not installed"

docker compose version >/dev/null

ip -4 addr | grep -qF "${HOST_IP}/" || fail "${HOST_IP} is not configured on this host"

[ -s "$ALERT_TOPIC_FILE" ] || fail "missing existing R515 alert topic: $ALERT_TOPIC_FILE"
[ -f "$ALERT_CONFIG" ] || fail "missing Alertmanager config: $ALERT_CONFIG"

curl -fsS --max-time 5 "http://${HOST_IP}:9093/-/ready" >/dev/null || \
  fail "Alertmanager is not ready on ${HOST_IP}:9093"

for c in alertmanager radarr sonarr seerr; do
  if docker ps --format '{{.Names}}' | grep -qx "$c"; then
    pass "container running: $c"
  else
    warn "container not found by exact name: $c"
  fi
done

section "CREATE SEPARATE MEDIA TOPIC"

mkdir -p "$MEDIA_DIR"

if [ ! -s "$MEDIA_TOPIC_FILE" ]; then
  (
    umask 077
    printf 'r515-media-%s\n' "$(openssl rand -hex 18)" > "$MEDIA_TOPIC_FILE"
  )
  chmod 0600 "$MEDIA_TOPIC_FILE"
  pass "created private media ntfy topic"
else
  chmod 0600 "$MEDIA_TOPIC_FILE"
  pass "existing media ntfy topic retained"
fi

MEDIA_TOPIC="$(tr -d '\r\n' < "$MEDIA_TOPIC_FILE")"
[ -n "$MEDIA_TOPIC" ] || fail "media topic is empty"

echo
echo "Subscribe to this as a NEW topic in the ntfy app:"
echo
echo "  Server: https://ntfy.sh"
echo "  Name:   R515 Media"
echo "  Topic:  $MEDIA_TOPIC"
echo
echo "Do not paste this topic into chat or commit it to GitHub."
echo
read -rp "After R515 Media is subscribed on your phone, press Enter... " _

section "WRITE CLEAN NOTIFICATION BRIDGE"

mkdir -p "$BRIDGE_DIR"

cat > "$BRIDGE_PY" <<'PY'
#!/usr/bin/env python3
import json
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "0.0.0.0"
PORT = 8787
NTFY_URL = "https://ntfy.sh/"
ALERT_TOPIC_FILE = "/run/secrets/alert-topic"
MEDIA_TOPIC_FILE = "/run/secrets/media-topic"

COUNTS = {
    "alertmanager_requests": 0,
    "alertmanager_publishes": 0,
    "media_test_publishes": 0,
}


def read_secret(path):
    with open(path, "r", encoding="utf-8") as f:
        value = f.read().strip()
    if not value:
        raise RuntimeError(f"secret file is empty: {path}")
    return value


ALERT_TOPIC = read_secret(ALERT_TOPIC_FILE)
MEDIA_TOPIC = read_secret(MEDIA_TOPIC_FILE)


def publish(topic, title, message, priority=3, tags=None):
    payload = {
        "topic": topic,
        "title": str(title)[:200],
        "message": str(message)[:3500],
        "priority": int(priority),
    }
    if tags:
        payload["tags"] = tags

    req = urllib.request.Request(
        NTFY_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        if not 200 <= r.status < 300:
            raise RuntimeError(f"ntfy returned HTTP {r.status}")


def clean_text(value):
    if value is None:
        return ""
    return " ".join(str(value).split())


def alert_summary(alert):
    annotations = alert.get("annotations") or {}
    labels = alert.get("labels") or {}
    return (
        clean_text(annotations.get("summary"))
        or clean_text(labels.get("alertname"))
        or "R515 alert"
    )


def alert_description(alert):
    annotations = alert.get("annotations") or {}
    return clean_text(annotations.get("description"))


def format_alertmanager(data):
    status = clean_text(data.get("status")).lower() or "firing"
    alerts = data.get("alerts") or []

    if not alerts:
        alerts = [{"labels": {"alertname": "R515Alert"}, "annotations": {}}]

    severities = [
        clean_text((a.get("labels") or {}).get("severity")).lower()
        for a in alerts
    ]

    if "critical" in severities:
        severity = "critical"
    elif "warning" in severities:
        severity = "warning"
    else:
        severity = "info"

    if len(alerts) == 1:
        summary = alert_summary(alerts[0])
        description = alert_description(alerts[0])

        if status == "resolved":
            title = f"Resolved: {summary}"
            message = description or "The alert condition has cleared."
            priority = 3
            tags = ["white_check_mark"]
        else:
            title = summary
            message = description or f"R515 alert is firing ({severity})."
            priority = 5 if severity == "critical" else 4 if severity == "warning" else 3
            tags = ["rotating_light"] if severity == "critical" else ["warning"] if severity == "warning" else ["information_source"]

        return title, message, priority, tags

    summaries = [alert_summary(a) for a in alerts]
    body = "\n".join(f"• {s}" for s in summaries[:12])
    if len(summaries) > 12:
        body += f"\n• +{len(summaries)-12} more"

    if status == "resolved":
        return (
            f"Resolved: {len(alerts)} R515 alerts",
            body,
            3,
            ["white_check_mark"],
        )

    priority = 5 if severity == "critical" else 4 if severity == "warning" else 3
    tags = ["rotating_light"] if severity == "critical" else ["warning"] if severity == "warning" else ["information_source"]
    return (
        f"{len(alerts)} R515 {severity} alerts",
        body,
        priority,
        tags,
    )


class Handler(BaseHTTPRequestHandler):
    server_version = "R515NotificationBridge/1.0"

    def _json(self, status, obj):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _empty(self, status=204):
        self.send_response(status)
        self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            self._json(200, {"status": "ok"})
            return
        if self.path == "/stats":
            self._json(200, COUNTS)
            return
        self._json(404, {"error": "not found"})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)

        try:
            data = json.loads(raw.decode("utf-8")) if raw else {}
        except Exception:
            self._json(400, {"error": "invalid json"})
            return

        try:
            if self.path == "/alertmanager":
                COUNTS["alertmanager_requests"] += 1
                title, message, priority, tags = format_alertmanager(data)
                publish(ALERT_TOPIC, title, message, priority, tags)
                COUNTS["alertmanager_publishes"] += 1
                self._empty()
                return

            if self.path == "/test/alert":
                publish(
                    ALERT_TOPIC,
                    "R515 Notifications Ready",
                    "Clean Alertmanager notification formatting is working.",
                    3,
                    ["white_check_mark"],
                )
                self._empty()
                return

            if self.path == "/test/media":
                publish(
                    MEDIA_TOPIC,
                    "R515 Media",
                    "Media notification topic is connected and ready.",
                    3,
                    ["movie_camera", "white_check_mark"],
                )
                COUNTS["media_test_publishes"] += 1
                self._empty()
                return

            self._json(404, {"error": "not found"})
        except Exception as e:
            print(f"notification publish failed: {e}", flush=True)
            self._json(502, {"error": "notification publish failed"})

    def log_message(self, fmt, *args):
        print(f"{self.client_address[0]} {fmt % args}", flush=True)


if __name__ == "__main__":
    print(f"R515 notification bridge listening on {HOST}:{PORT}", flush=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
PY

cat > "$BRIDGE_COMPOSE" <<EOF
services:
  notification-bridge:
    image: python:3.13-alpine
    container_name: notification-bridge
    restart: unless-stopped

    ports:
      - "${HOST_IP}:${BRIDGE_PORT}:${BRIDGE_PORT}"

    volumes:
      - ./bridge.py:/app/bridge.py:ro
      - ${ALERT_TOPIC_FILE}:/run/secrets/alert-topic:ro
      - ${MEDIA_TOPIC_FILE}:/run/secrets/media-topic:ro

    command:
      - python
      - -u
      - /app/bridge.py
EOF

chmod 0644 "$BRIDGE_PY" "$BRIDGE_COMPOSE"
docker compose -f "$BRIDGE_COMPOSE" config >/dev/null
pass "notification bridge Compose validates"

if ss -lntH | awk '{print $4}' | grep -Eq "(^|:)${BRIDGE_PORT}$"; then
  if docker ps --format '{{.Names}}' | grep -qx notification-bridge; then
    echo "INFO: existing notification-bridge container detected"
  else
    fail "TCP ${BRIDGE_PORT} is already in use by something else"
  fi
fi

docker compose -f "$BRIDGE_COMPOSE" pull
docker compose -f "$BRIDGE_COMPOSE" up -d

for i in $(seq 1 30); do
  if curl -fsS --max-time 3 "http://${HOST_IP}:${BRIDGE_PORT}/health" >/dev/null 2>&1; then
    pass "notification bridge is healthy"
    break
  fi
  if [ "$i" -eq 30 ]; then
    docker compose -f "$BRIDGE_COMPOSE" logs --tail=100 || true
    fail "notification bridge did not become healthy"
  fi
  sleep 2
done

section "SEND TOPIC TESTS"

curl -fsS -X POST \
  -H 'Content-Type: application/json' \
  --data '{}' \
  "http://${HOST_IP}:${BRIDGE_PORT}/test/media" >/dev/null
pass "media test published"

curl -fsS -X POST \
  -H 'Content-Type: application/json' \
  --data '{}' \
  "http://${HOST_IP}:${BRIDGE_PORT}/test/alert" >/dev/null
pass "clean alert-topic test published"

section "PATCH ALERTMANAGER TO CLEAN BRIDGE"

BACKUP="${ALERT_CONFIG}.pre-clean-bridge-${STAMP}"
cp -a "$ALERT_CONFIG" "$BACKUP"
chmod 0600 "$BACKUP"

python3 - "$ALERT_CONFIG" "$HOST_IP" "$BRIDGE_PORT" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
host = sys.argv[2]
port = sys.argv[3]
target = f'http://{host}:{port}/alertmanager'

lines = path.read_text().splitlines()
already = [i for i, line in enumerate(lines) if target in line]
if already:
    print("INFO: Alertmanager already points to notification bridge")
else:
    matches = [
        i for i, line in enumerate(lines)
        if "ntfy.sh/" in line and "template=alertmanager" in line and "url:" in line
    ]
    if len(matches) != 1:
        raise SystemExit(
            f"ERROR: expected exactly one existing ntfy Alertmanager URL, found {len(matches)}"
        )

    i = matches[0]
    indent = re.match(r"^(\s*)", lines[i]).group(1)
    lines[i] = f'{indent}- url: "{target}"'
    path.write_text("\n".join(lines) + "\n")
    print("PASS: replaced generic ntfy Alertmanager template URL with clean local bridge")
PY

chmod 0644 "$ALERT_CONFIG"

ALERT_IMAGE="$(docker inspect alertmanager --format '{{.Config.Image}}' 2>/dev/null || true)"
[ -n "$ALERT_IMAGE" ] || ALERT_IMAGE="prom/alertmanager:v0.34.0"

docker run --rm \
  --entrypoint /bin/amtool \
  -v "${ALERT_CONFIG}:/etc/alertmanager/alertmanager.yml:ro" \
  "$ALERT_IMAGE" \
  check-config /etc/alertmanager/alertmanager.yml >/dev/null

pass "Alertmanager configuration validates"

docker kill --signal=HUP alertmanager >/dev/null

for i in $(seq 1 20); do
  if curl -fsS --max-time 3 "http://${HOST_IP}:9093/-/ready" >/dev/null 2>&1; then
    pass "Alertmanager ready after reload"
    break
  fi
  if [ "$i" -eq 20 ]; then
    fail "Alertmanager did not return ready after reload"
  fi
  sleep 1
done

section "END-TO-END ALERTMANAGER TEST"

BEFORE="$(
  curl -fsS "http://${HOST_IP}:${BRIDGE_PORT}/stats" |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["alertmanager_requests"])'
)"

python3 - > /tmp/r515-alert-test.json <<'PY'
import datetime
import json

now = datetime.datetime.now(datetime.timezone.utc)
end = now + datetime.timedelta(minutes=2)

print(json.dumps([{
    "labels": {
        "alertname": "R515NotificationFormattingTest",
        "severity": "info",
        "instance": "docker01"
    },
    "annotations": {
        "summary": "R515 notification formatting test",
        "description": "Alertmanager reached the clean notification bridge successfully."
    },
    "startsAt": now.isoformat(),
    "endsAt": end.isoformat()
}]))
PY

curl -fsS \
  -H 'Content-Type: application/json' \
  -X POST \
  --data-binary @/tmp/r515-alert-test.json \
  "http://${HOST_IP}:9093/api/v2/alerts" >/dev/null

echo "Waiting for Alertmanager's 20-second group delay..."

SEEN=0
for _ in $(seq 1 50); do
  NOW="$(
    curl -fsS "http://${HOST_IP}:${BRIDGE_PORT}/stats" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["alertmanager_requests"])'
  )"
  if [ "$NOW" -gt "$BEFORE" ]; then
    SEEN=1
    break
  fi
  sleep 1
done

[ "$SEEN" -eq 1 ] || fail "Alertmanager test did not reach notification bridge"
pass "Alertmanager -> clean bridge -> ntfy path accepted the test"

section "FINAL STATUS"

curl -fsS "http://${HOST_IP}:${BRIDGE_PORT}/stats"
echo
echo

echo "Infrastructure alerts:"
echo "  Prometheus -> Alertmanager -> clean bridge -> existing R515 Alerts ntfy topic"
echo
echo "Media notifications:"
echo "  Radarr / Sonarr / Seerr -> native ntfy connector -> separate R515 Media topic"
echo
echo "Media topic is stored at:"
echo "  $MEDIA_TOPIC_FILE"
echo
echo "Topic value for the three app connectors:"
echo "  $MEDIA_TOPIC"
echo
echo "Bridge health:"
echo "  http://${HOST_IP}:${BRIDGE_PORT}/health"
echo
echo "IMPORTANT:"
echo "  Healthchecks.io still uses its existing external ntfy integration."
echo "  Its formatting can be cleaned separately without making it depend on this server."
echo
echo "=== BASE NOTIFICATION SYSTEM COMPLETE ==="
