# Windows backup pull

This document tracks the simple off-server backup copy from the R515 to the Windows PC.

## Current status

The R515 stores local backup archives under:

```text
/mnt/storage/backups
```

The Samba share exposes that path on Windows as:

```text
\\192.168.10.135\media\backups
```

The Windows PC keeps a copied backup tree at:

```text
D:\R515-Backups\backups
```

The 2026-07-30 SMS/audit backup folder was verified copied to the Windows PC. Confirmed copied files:

```text
srv-docker-after-smsbot-jellyfin-media-fixes.tar.gz
srv-docker-after-smsbot-status-downloads.tar.gz
srv-docker-after-smsbot-recently-added-tv-queue-test.tar.gz
srv-docker-after-smsbot-audit-log.tar.gz
```

## Pull script

Save this on the Windows PC as:

```text
D:\R515-Backups\pull-r515-backups.ps1
```

Script:

```powershell
$Source = "\\192.168.10.135\media\backups"
$Destination = "D:\R515-Backups\backups"
$Log = "D:\R515-Backups\backup-copy.log"

New-Item -ItemType Directory -Path $Destination -Force | Out-Null

Write-Host "Pulling R515 backups..."
Write-Host "Source:      $Source"
Write-Host "Destination: $Destination"
Write-Host ""

robocopy $Source $Destination /E /R:2 /W:5 /FFT /COPY:DAT /DCOPY:DAT /ETA /TEE /LOG+:$Log

$Code = $LASTEXITCODE

Write-Host ""
Write-Host "Robocopy exit code: $Code"

if ($Code -le 7) {
    Write-Host "Backup copy completed successfully."
    exit 0
} else {
    Write-Host "Backup copy failed or was interrupted."
    exit $Code
}
```

Run manually with:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\R515-Backups\pull-r515-backups.ps1"
```

## Robocopy notes

- `/E` copies subdirectories, including empty ones.
- `/ETA` shows estimated time and progress for large files.
- `/TEE` shows output in the terminal and also writes it to the log.
- `/LOG+:...` appends to the existing log instead of replacing it.
- `/R:2 /W:5` retries failed files twice and waits 5 seconds between retries.
- `/FFT` helps with timestamp differences between Windows and Samba/Linux filesystems.
- The script intentionally does not use `/MIR`, so deleting a backup on the R515 does not automatically delete the Windows copy.

## Log file

Robocopy logs are appended here:

```text
D:\R515-Backups\backup-copy.log
```

## Current limitation

This is a good basic off-server copy for configuration backups, but it is still manual unless a Windows Scheduled Task is added later. Before adding Immich or trusting the server with irreplaceable photos, add either a scheduled run, external drive copy, or cloud/object-storage destination.
