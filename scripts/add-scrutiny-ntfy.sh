#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/srv/docker/monitoring/scrutiny"
COMPOSE="${BASE}/docker-compose.yml"
ENVFILE="${BASE}/notify.env"
TOPIC_FILE="/srv/docker/monitoring/alerting/ntfy-topic.txt"
HOST_IP="192.168.10.135"
PORT="8082"

pass(){ echo "PASS: $*"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "Run as root on docker01."
command -v pveversion >/dev/null 2>&1 && fail "Run this on docker01, not the Proxmox host."
command -v docker >/dev/null 2>&1 || fail "Docker not found."
docker compose version >/dev/null || fail "Docker Compose plugin not found."
[ -f "$COMPOSE" ] || fail "Missing Scrutiny Compose file."
[ -s "$TOPIC_FILE" ] || fail "Missing R515 Alerts topic file."

curl -fsS --max-time 5 "http://${HOST_IP}:${PORT}/api/health" >/dev/null ||
  fail "Scrutiny is not healthy before changes."

TOPIC="$(tr -d '\r\n' < "$TOPIC_FILE")"
[ -n "$TOPIC" ] || fail "Alert topic is empty."

(
  umask 077
  printf '%s\n' "SCRUTINY_NOTIFY_URLS=ntfy://ntfy.sh/${TOPIC}?priority=5&tags=warning" > "$ENVFILE"
)
chmod 0600 "$ENVFILE"
pass "Wrote root-only Scrutiny ntfy configuration."

python3 - "$COMPOSE" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1])
lines=p.read_text().splitlines()
start=next((i for i,l in enumerate(lines) if re.match(r'^  web:\s*$',l)),None)
if start is None:
    raise SystemExit("ERROR: web service not found")
end=next((i for i in range(start+1,len(lines)) if re.match(r'^  [A-Za-z0-9_.-]+:\s*$',lines[i])),len(lines))
if any("./notify.env" in l for l in lines[start:end]):
    print("PASS: notify.env already referenced")
else:
    env_idx=next((i for i in range(start+1,end) if re.match(r'^    env_file:\s*$',lines[i])),None)
    if env_idx is not None:
        lines.insert(env_idx+1,"      - ./notify.env")
    else:
        insert=next((i for i in range(start+1,end) if re.match(r'^    environment:\s*$',lines[i])),start+1)
        lines[insert:insert]=["    env_file:","      - ./notify.env"]
    p.write_text("\n".join(lines)+"\n")
    print("PASS: added notify.env to Scrutiny web service")
PY

cd "$BASE"
docker compose config >/dev/null
docker compose up -d --no-deps --force-recreate web

for i in $(seq 1 30); do
  if curl -fsS --max-time 3 "http://${HOST_IP}:${PORT}/api/health" >/dev/null 2>&1; then
    pass "Scrutiny healthy after recreation."
    break
  fi
  [ "$i" -lt 30 ] || fail "Scrutiny failed to become healthy."
  sleep 2
done

HTTP="$(curl -sS -o /tmp/scrutiny-notify-test.out -w '%{http_code}' -X POST "http://${HOST_IP}:${PORT}/api/health/notify")"
case "$HTTP" in
  200|201|202|204) pass "Scrutiny ntfy test succeeded (HTTP $HTTP)." ;;
  *)
    cat /tmp/scrutiny-notify-test.out || true
    echo
    fail "Scrutiny ntfy test failed (HTTP $HTTP)."
    ;;
esac
rm -f /tmp/scrutiny-notify-test.out
echo "Scrutiny SMART notifications are enabled on the existing R515 Alerts topic."
