# Restore procedure and restore-read test

This document tracks the first backup restore validation for the R515 Docker stack.

## What was tested

A safe restore-read test was run against the newest SMS/audit backup archive:

```text
/mnt/storage/backups/2026-07-30/srv-docker-after-smsbot-audit-log.tar.gz
```

The test intentionally extracted only a few important files into a separate restore-test folder instead of overwriting the live `/srv/docker` folder.

Test folder used:

```text
/mnt/storage/restore-tests/restore-read-2026-08-02-032046
```

## Files verified

The backup archive was confirmed to contain the expected Docker stack paths:

```text
srv/docker/.env
srv/docker/smsbot/app.py
srv/docker/docker-compose.yml
```

After extraction, the following files were verified in the restore-test folder:

```text
srv/docker/docker-compose.yml
srv/docker/.env
srv/docker/smsbot/app.py
```

Important: `.env` was verified as present, but its contents were not printed.

## Compose validation

The restored compose file was checked without starting containers:

```bash
cd /mnt/storage/restore-tests/restore-read-2026-08-02-032046/srv/docker
sudo docker compose --env-file .env -f docker-compose.yml config -q
```

Result:

```text
OK: docker compose config is valid
Restore-read test passed.
```

## Safe restore-read command

Use this pattern to validate a backup without touching the live stack:

```bash
cat > /tmp/restore-read-test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BACKUP="/mnt/storage/backups/2026-07-30/srv-docker-after-smsbot-audit-log.tar.gz"
TESTDIR="/mnt/storage/restore-tests/restore-read-$(date +%F-%H%M%S)"

echo "Backup: $BACKUP"
echo "Test folder: $TESTDIR"

sudo mkdir -p "$TESTDIR"

echo
echo "=== Extract selected files only ==="
sudo tar -xzf "$BACKUP" -C "$TESTDIR" \
  srv/docker/docker-compose.yml \
  srv/docker/.env \
  srv/docker/smsbot/app.py

echo
echo "=== Check restored files ==="
ls -lah "$TESTDIR/srv/docker"
ls -lah "$TESTDIR/srv/docker/smsbot/app.py"

test -f "$TESTDIR/srv/docker/docker-compose.yml" && echo "OK: docker-compose.yml found"
test -f "$TESTDIR/srv/docker/.env" && echo "OK: .env found, not printing contents"
test -f "$TESTDIR/srv/docker/smsbot/app.py" && echo "OK: smsbot/app.py found"

echo
echo "=== Validate compose syntax without starting anything ==="
cd "$TESTDIR/srv/docker"
sudo docker compose --env-file .env -f docker-compose.yml config -q
echo "OK: docker compose config is valid"

echo
echo "Restore-read test passed."
echo "Test folder left here:"
echo "$TESTDIR"
EOF

bash /tmp/restore-read-test.sh
```

## Actual full restore outline

Do not run this casually. This is the rough emergency process for restoring the Docker stack after a failed server/config state.

1. Stop containers first:

```bash
cd /srv/docker
sudo docker compose down
```

2. Move the broken live folder aside instead of deleting it:

```bash
sudo mv /srv/docker /srv/docker.broken-$(date +%F-%H%M%S)
```

3. Extract the chosen backup to `/` so `srv/docker/...` lands back at `/srv/docker/...`:

```bash
sudo tar -xzf /mnt/storage/backups/<date>/<backup-file>.tar.gz -C /
```

4. Check restored files without printing secrets:

```bash
ls -lah /srv/docker
test -f /srv/docker/.env && echo "OK: .env restored, not printing contents"
sudo docker compose --env-file /srv/docker/.env -f /srv/docker/docker-compose.yml config -q
```

5. Start the stack only after the compose config validates:

```bash
cd /srv/docker
sudo docker compose up -d
```

6. Check service health:

```bash
sudo docker ps
curl http://192.168.10.135:5070/health
```

## Safety notes

- Never print or commit `.env` contents.
- Prefer testing in `/mnt/storage/restore-tests/...` before restoring over live paths.
- Move broken folders aside instead of deleting them.
- Keep PC copies under `D:\R515-Backups\backups` so a copy exists off the R515.
- This restore-read test validates key config files only. It does not prove every app database is perfectly consistent, because many app databases were backed up while containers were running.
