#!/usr/bin/env bash
set -Eeuo pipefail

MOVIE_ROOT="/mnt/storage/media/movies"
STATE_DIR="/var/lib/r515-media-language"
MARKER="${STATE_DIR}/scan-marker"
FIXER="/srv/docker/scripts/r515-set-english-audio-default.py"
SCANNER="/srv/docker/scripts/r515-english-audio-scan.sh"
SERVICE="/etc/systemd/system/r515-english-audio.service"
TIMER="/etc/systemd/system/r515-english-audio.timer"

pass(){ echo "PASS: $*"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }
section(){ printf '\n=== %s ===\n' "$1"; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "Run as root on docker01."
command -v pveversion >/dev/null 2>&1 && fail "Run this on docker01, not the Proxmox host."
[ -d "$MOVIE_ROOT" ] || fail "Movie library not found: $MOVIE_ROOT"

for cmd in systemctl findmnt flock python3 stat; do
  command -v "$cmd" >/dev/null || fail "$cmd not found."
done

findmnt -T /mnt/storage >/dev/null || fail "/mnt/storage is not mounted."

section "MKVTOOLNIX"

if ! command -v mkvmerge >/dev/null 2>&1 || ! command -v mkvpropedit >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends mkvtoolnix
fi

command -v mkvmerge >/dev/null || fail "mkvmerge is unavailable."
command -v mkvpropedit >/dev/null || fail "mkvpropedit is unavailable."
pass "MKVToolNix is available."

section "INSTALL FIXER"

mkdir -p /srv/docker/scripts "$STATE_DIR"

cat > "$FIXER" <<'PY'
#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys

if len(sys.argv) != 2:
    print("usage: r515-set-english-audio-default.py <movie.mkv>", file=sys.stderr)
    raise SystemExit(2)

path = sys.argv[1]

if not os.path.isfile(path):
    print(f"SKIP missing file: {path}")
    raise SystemExit(0)

if not path.lower().endswith(".mkv"):
    print(f"SKIP non-MKV: {path}")
    raise SystemExit(0)

try:
    info = json.loads(
        subprocess.check_output(
            ["mkvmerge", "-J", path],
            text=True,
            stderr=subprocess.STDOUT,
        )
    )
except subprocess.CalledProcessError as exc:
    print(f"ERROR mkvmerge could not inspect: {path}", file=sys.stderr)
    print(exc.output, file=sys.stderr)
    raise SystemExit(1)

audio = [t for t in (info.get("tracks") or []) if t.get("type") == "audio"]

if not audio:
    print(f"SKIP no audio tracks: {path}")
    raise SystemExit(0)

def props(track):
    return track.get("properties") or {}

def language(track):
    p = props(track)
    return str(p.get("language_ietf") or p.get("language") or "und").lower()

def track_name(track):
    return str(props(track).get("track_name") or "").strip()

def is_english(track):
    p = props(track)
    lang = str(p.get("language") or "").lower()
    ietf = str(p.get("language_ietf") or "").lower()
    return lang in {"eng", "en"} or ietf == "en" or ietf.startswith("en-")

def is_unlabeled(track):
    return language(track) in {"", "und", "unknown"}

def is_commentary(track):
    name = track_name(track).lower()
    bad = (
        "commentary",
        "director",
        "description",
        "descriptive",
        "audio description",
        "visually impaired",
    )
    return any(word in name for word in bad)

def name_says_english(track):
    name = track_name(track).lower()
    if not name:
        return False
    return bool(re.search(r"(^|[^a-z])(english|eng)([^a-z]|$)", name))

def candidate(audio_index, track, reason):
    p = props(track)
    return {
        "audio_index": audio_index,
        "track": track,
        "commentary": is_commentary(track),
        "channels": int(p.get("audio_channels") or 0),
        "default": bool(p.get("default_track")),
        "reason": reason,
    }

def choose_ranked(candidates):
    candidates.sort(
        key=lambda x: (
            x["commentary"],
            -x["channels"],
            -int(x["default"]),
            x["audio_index"],
        )
    )
    return candidates[0]

tagged_english = [
    candidate(idx, track, "tagged English")
    for idx, track in enumerate(audio, start=1)
    if is_english(track)
]

chosen = None

if tagged_english:
    chosen = choose_ranked(tagged_english)
else:
    named_english = [
        candidate(idx, track, "track name says English")
        for idx, track in enumerate(audio, start=1)
        if is_unlabeled(track) and name_says_english(track)
    ]

    if named_english:
        chosen = choose_ranked(named_english)

    elif len(audio) == 1:
        chosen = candidate(1, audio[0], "single audio track")

if chosen is None:
    details = []
    for idx, track in enumerate(audio, start=1):
        name = track_name(track)
        suffix = f":{name}" if name else ""
        details.append(f"a{idx}={language(track)}{suffix}")

    print(f"AMBIGUOUS_NO_ENGLISH audio={','.join(details)} :: {path}")
    raise SystemExit(0)

chosen_index = chosen["audio_index"]

default_indexes = [
    idx
    for idx, track in enumerate(audio, start=1)
    if bool(props(track).get("default_track"))
]

if default_indexes == [chosen_index]:
    if chosen["reason"] == "tagged English":
        label = "English"
    elif chosen["reason"] == "track name says English":
        label = "English-by-name"
    else:
        label = "single audio track"

    print(f"OK already default ({label}) a{chosen_index}: {path}")
    raise SystemExit(0)

cmd = ["mkvpropedit", path]

for idx in range(1, len(audio) + 1):
    cmd.extend(
        [
            "--edit",
            f"track:a{idx}",
            "--set",
            f"flag-default={1 if idx == chosen_index else 0}",
        ]
    )

try:
    subprocess.run(cmd, check=True)
except subprocess.CalledProcessError as exc:
    print(f"ERROR mkvpropedit failed ({exc.returncode}): {path}", file=sys.stderr)
    raise SystemExit(exc.returncode or 1)

p = props(chosen["track"])
name = track_name(chosen["track"])
lang = language(chosen["track"])
extra = f" [{name}]" if name else ""

if chosen["reason"] == "single audio track" and is_unlabeled(chosen["track"]):
    description = "single unlabeled audio track"
else:
    description = f"{chosen['reason']} {lang}"

print(
    f"CHANGED default audio -> {description} a{chosen_index} "
    f"{chosen['channels']}ch{extra}: {path}"
)

PY

chmod 0755 "$FIXER"

cat > "$SCANNER" <<'SCAN'
#!/usr/bin/env bash
set -Eeuo pipefail

MOVIE_ROOT="/mnt/storage/media/movies"
STATE_DIR="/var/lib/r515-media-language"
MARKER="${STATE_DIR}/scan-marker"
FIXER="/srv/docker/scripts/r515-set-english-audio-default.py"

mkdir -p "$STATE_DIR"

if [ ! -e "$MARKER" ]; then
    touch -d '1970-01-01 00:00:00 UTC' "$MARKER"
fi

NOW="$(date +%s)"
FAILED=0
SEEN=0

while IFS= read -r -d '' file; do
    SEEN=$((SEEN + 1))

    CTIME="$(stat -c '%Z' "$file" 2>/dev/null || echo "$NOW")"
    AGE=$((NOW - CTIME))

    if [ "$AGE" -lt 180 ]; then
        echo "WAIT file changed less than 3 minutes ago: $file"
        continue
    fi

    if ! "$FIXER" "$file"; then
        FAILED=1
    fi
done < <(
    find "$MOVIE_ROOT" \
        -type f \
        -iname '*.mkv' \
        -cnewer "$MARKER" \
        -print0
)

if [ "$FAILED" -ne 0 ]; then
    echo "ERROR: one or more movie files could not be processed; marker not advanced." >&2
    exit 1
fi

touch -d '10 minutes ago' "$MARKER"

echo "PASS: English-audio scan completed; candidates seen: $SEEN"
SCAN

chmod 0755 "$SCANNER"

pass "English audio fixer and incremental scanner installed."

section "INSTALL SYSTEMD AUTOMATION"

cat > "$SERVICE" <<EOF
[Unit]
Description=Set English as default audio for newly imported R515 movies
RequiresMountsFor=/mnt/storage
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/flock -n /run/lock/r515-english-audio.lock $SCANNER
TimeoutStartSec=2h
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
EOF

cat > "$TIMER" <<'EOF'
[Unit]
Description=Check newly imported movies for English default audio

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Persistent=true
AccuracySec=30s
Unit=r515-english-audio.service

[Install]
WantedBy=timers.target
EOF

chmod 0644 "$SERVICE" "$TIMER"
systemctl daemon-reload
systemctl enable --now r515-english-audio.timer
systemctl reset-failed r515-english-audio.service 2>/dev/null || true

pass "Five-minute automatic movie-language timer enabled."

section "INITIAL LIBRARY PASS"

echo "Scanning the current MKV movie library once."
echo "This reads MKV headers only; it does not re-encode the movies."
echo

if ! systemctl start r515-english-audio.service; then
    echo
    systemctl status r515-english-audio.service --no-pager -l || true
    echo
    journalctl -u r515-english-audio.service -n 100 --no-pager || true
    fail "Initial English-audio scan failed."
fi

pass "Initial library scan completed."

section "FINAL STATUS"

systemctl status r515-english-audio.timer --no-pager -l
echo
systemctl list-timers r515-english-audio.timer --all --no-pager
echo
echo "Recent language-fixer log:"
journalctl -u r515-english-audio.service -n 30 --no-pager
echo
echo "Behavior:"
echo "  - scans newly imported/changed MKV movies every 5 minutes"
echo "  - waits at least 3 minutes before editing a changed file"
echo "  - selects an English audio track when one exists"
echo "  - avoids commentary/descriptive English tracks when possible"
echo "  - clears the default flag from other audio tracks"
echo "  - does not re-encode the movie"
echo "  - accepts a single unlabeled audio track as the only safe playback choice"\necho "  - recognizes unlabeled tracks whose title explicitly says English/ENG"\necho "  - logs AMBIGUOUS_NO_ENGLISH and leaves multi-track ambiguous files unchanged"
echo "  - keeps a 10-minute overlap so imports are not missed"
echo
echo "=== R515 ENGLISH AUDIO AUTOMATION COMPLETE ==="
