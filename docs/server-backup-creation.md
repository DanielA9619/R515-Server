# Server-side backup creation

This document tracks the Debian-side script that creates R515 configuration backup archives before they are copied to the Windows PC.

## Current status

A repeatable backup creation script was installed at:

```text
/srv/docker/scripts/backup-r515-configs.sh
```

It was tested with this label:

```bash
/srv/docker/scripts/backup-r515-configs.sh after-restore-read-test
```

Created backup:

```text
/mnt/storage/backups/2026-08-02/r515-configs-after-restore-read-test-2026-08-02-032545.tar.gz
```

Reported size:

```text
2.7G
```

The new backup was then pulled to the Windows PC with the tested PowerShell/Robocopy script.

Confirmed Windows copy:

```text
D:\R515-Backups\backups\2026-08-02\r515-configs-after-restore-read-test-2026-08-02-032545.tar.gz
```

Robocopy reported exit code `1`, which is expected for a successful run where at least one file was copied. The run copied the new `2026-08-02` directory and the 2.6G backup file.

## Script contents

```bash
#!/usr/bin/env bash
set -euo pipefail

LABEL="${1:-manual}"
DATE="$(date +%F)"
TIME="$(date +%H%M%S)"
SAFE_LABEL="$(echo "$LABEL" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//; s/-$//')"

DEST="/mnt/storage/backups/$DATE"
ARCHIVE="$DEST/r515-configs-$SAFE_LABEL-$DATE-$TIME.tar.gz"

echo "Creating backup:"
echo "$ARCHIVE"

sudo mkdir -p "$DEST"

cd /

sudo tar -czf "$ARCHIVE" \
  srv/docker \
  etc/samba/smb.conf

echo
echo "Backup created:"
ls -lh "$ARCHIVE"

echo
echo "Reminder: this includes /srv/docker/.env, but the script does not print it."
```

## What it backs up

Current targets:

```text
/srv/docker
/etc/samba/smb.conf
```

This includes Docker Compose files, container config directories, the local SMS bot, AdGuard/Homarr/Seerr/Radarr/Sonarr/qBittorrent-related config folders, and `/srv/docker/.env`.

## Warning notes

During the test run, tar printed these warnings:

```text
tar: srv/docker/uptime-kuma/data/run/mariadb.sock: socket ignored
tar: srv/docker/qbittorrent/config/qBittorrent/ipc-socket: socket ignored
```

These are expected for live runtime socket files and do not mean the archive failed. The archive was still created successfully.

## Current manual rhythm

1. Create a server-side backup on Debian:

```bash
/srv/docker/scripts/backup-r515-configs.sh <label>
```

2. Pull the backup tree to the Windows PC:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\R515-Backups\pull-r515-backups.ps1"
```

3. Confirm the new backup file appears under:

```text
D:\R515-Backups\backups
```

## Safety notes

- The backup includes `/srv/docker/.env`; do not print or commit its contents.
- The script creates a backup but does not stop containers first, so some app databases may not be perfectly app-consistent.
- For now this is acceptable as a practical config backup. Before relying on this for irreplaceable photo data or Immich, improve database-aware backups and add a second destination.
