# R515 Home Server Roadmap

This is the current planned build order for the R515 home server.

## Done

- Proxmox installed on Dell PowerEdge R515
- Debian Docker VM `docker01` created
- `docker01` IP set/reserved as `192.168.10.135`
- Docker installed
- Samba installed
- 3TB HDD mounted at `/mnt/storage`
- Jellyfin running in Docker
- Caddy running in Docker
- Remote Jellyfin access working through `mediahubdaniel.duckdns.org`
- UniFi forwards WAN ports `80` and `443` to Caddy
- Old Windows Jellyfin/Caddy/DuckDNS services disabled
- DuckDNS updater cron job added to Debian
- Initial config backups made for `/srv/docker` and `/etc/samba/smb.conf`
- `docker01` configured to auto-start with Proxmox
- Quadro P400 passed through from Proxmox to `docker01`
- NVIDIA driver and NVIDIA Container Toolkit installed
- Jellyfin Compose configured with the NVIDIA runtime
- Jellyfin hardware transcoding confirmed with `jellyfin-ffmpeg` visible in `nvidia-smi`
- Jellyfin plugin catalog DNS issue fixed by explicitly using AdGuard DNS (`192.168.10.135`) in Docker Compose
- Initial Jellyfin audio-default cleanup completed for files where Russian was marked default and English was available
- Home Assistant OS VM created in Proxmox
- New HAOS VM is reachable at `192.168.10.127`
- HACS, Matter Server, Terminal & SSH, Studio Code Server, Google Drive Backup, and UniFi work completed on new HAOS VM
- Home Assistant migration paused safely while Raspberry Pi remains fallback
- Portainer installed
- Uptime Kuma installed
- Uptime Kuma monitors added for key services
- Uptime Kuma DNS issue fixed so the public Jellyfin monitor can resolve `mediahubdaniel.duckdns.org`
- qBittorrent installed
- Mullvad/Gluetun configured and confirmed healthy
- qBittorrent routed through Gluetun/Mullvad
- qBittorrent download paths configured
- qBittorrent monitor added in Uptime Kuma
- qBittorrent stalled-torrent issue fixed by binding qBittorrent to the correct VPN interface
- Fresh backup completed after qBittorrent + VPN was confirmed working
- Prowlarr installed
- Prowlarr authentication enabled
- qBittorrent added to Prowlarr as download client
- Prowlarr DNS issue fixed by explicitly using AdGuard DNS (`192.168.10.135`) in Docker Compose
- Prowlarr indexers added and confirmed working by the user
- Byparr added as an internal helper service on port `8191`
- Radarr installed for movies
- Radarr authentication enabled
- Radarr root folder configured as `/movies`
- qBittorrent added to Radarr as download client using host `gluetun` and category `radarr`
- Prowlarr connected to Radarr
- Radarr monitor added in Uptime Kuma
- Radarr quality profile configured for 1080p fallback with 4K upgrades
- Sonarr installed for TV
- Sonarr authentication enabled
- Sonarr root folder configured as `/tv`
- qBittorrent added to Sonarr as download client using host `gluetun` and category `sonarr`
- Prowlarr connected to Sonarr
- Sonarr monitor added in Uptime Kuma
- Sonarr quality profile configured for 1080p fallback with 4K upgrades
- Seerr installed as the LAN-only media request frontend on port `5055`
- Seerr connected to Jellyfin during setup
- Seerr Radarr and Sonarr setup started using the normal Radarr/Sonarr instances, not separate 4K servers
- Local SMS request bot installed on port `5070`
- SMS bot local health endpoint tested successfully
- SMS bot movie search and request flow tested successfully against Seerr
- SMS bot help command and TV search tested successfully
- SMS bot TV season request confirmation tested successfully: `TV Silo season 2` -> `1` submitted to Seerr and added items to the Sonarr queue
- The Silo queued items were manually deleted by the user before download, so no qBittorrent download was expected after that test
- SMS bot `Status` command tested successfully against Seerr and qBittorrent
- SMS bot `Downloads` command tested successfully and adjusted to hide completed/seeding torrents
- SMS bot `Recently added` command tested successfully against the read-only `/media` mount
- Fresh backup completed after SMS bot `Recently added` and TV queue test
- Audit logging added to SMS bot and tested with JSON-lines records under `/srv/docker/smsbot/data/audit.log`
- Fresh backup completed after SMS bot audit logging was added and tested
- Initial periodic PC copy of `/mnt/storage/backups` to Windows started with Robocopy
- Verified the 2026-07-30 SMS/audit backup folder copied to the Windows PC with Robocopy
- Windows backup pull script created and tested with Robocopy progress/ETA output
- SMS bot monitoring/dashboard entries added or confirmed in Uptime Kuma and Homarr
- Twilio preparation started, then intentionally paused: the `twilio` Python package is installed, the local `/sms` endpoint still works, and `/twilio-sms` exists but correctly rejects unsigned requests with `403 Forbidden`
- Restore-read test completed successfully against the newest SMS/audit backup without overwriting live files
- Repeatable Debian-side config backup script installed and tested at `/srv/docker/scripts/backup-r515-configs.sh`
- New backup from the Debian-side script was copied to the Windows PC with Robocopy
- AdGuard Home installed in Docker
- AdGuard Home dashboard reachable on the LAN
- AdGuard Home upstream DNS configured and server-side DNS tests passed
- AdGuard Home blocking confirmed with `doubleclick.net` resolving to `0.0.0.0` / `::`
- Main/default UniFi LAN DHCP DNS changed to `192.168.10.135`
- Whole-LAN AdGuard DNS rollout confirmed working by the user
- Fresh backup completed after AdGuard Home whole-LAN rollout
- Fresh backup completed after SMS bot status/downloads, Jellyfin plugin DNS, and media audio-default fixes

## Active validation

### Backups and off-server copies

Current approach:

```text
R515 local backups: /mnt/storage/backups
Windows PC copy:    D:\R515-Backups\backups
Samba path:         \\192.168.10.135\media\backups
```

Manual Robocopy from Windows has been tested. The `2026-07-30` backup folder is visible through Samba and the following newest SMS bot backup files were confirmed copied to the Windows PC:

```text
srv-docker-after-smsbot-jellyfin-media-fixes.tar.gz
srv-docker-after-smsbot-status-downloads.tar.gz
srv-docker-after-smsbot-recently-added-tv-queue-test.tar.gz
srv-docker-after-smsbot-audit-log.tar.gz
```

The reusable Windows script `D:\R515-Backups\pull-r515-backups.ps1` was tested and shows Robocopy progress/ETA output. Details are tracked in `docs/windows-backup-pull.md`.

The Debian-side backup script is installed at:

```text
/srv/docker/scripts/backup-r515-configs.sh
```

Current manual rhythm:

1. Create a config backup on Debian with `/srv/docker/scripts/backup-r515-configs.sh <label>`.
2. Pull backups to the Windows PC with `D:\R515-Backups\pull-r515-backups.ps1`.
3. Confirm the new file appears under `D:\R515-Backups\backups`.

Recommended next improvements:

1. Optionally create a Windows Scheduled Task to run the pull periodically.
2. Later, add a second destination such as an external drive or cloud/object storage before trusting Immich with irreplaceable photos.
3. Before Immich, make sure the Immich app database and photo library will have a database-aware backup plan.

### SMS request bot

Current status:

- Local FastAPI SMS bot is running on port `5070`.
- `/health` returns `{"status":"ok"}`.
- `/sms` works locally for approved sender testing.
- Movie search and request flow works through Seerr.
- Help command works.
- TV search and TV season request submission work through Seerr/Sonarr.
- `Status` reports Seerr/qBittorrent health, active/stalled/complete counts, and aggregate speed.
- `Downloads` reports not-yet-complete qBittorrent downloads and hides completed/seeding torrents.
- `Recently added` reports newest imported media from the read-only `/media` mount.
- Audit logging writes JSON-lines records under `/srv/docker/smsbot/data/audit.log`.
- SMS bot is tracked locally in Uptime Kuma and Homarr.
- Twilio prep is paused by choice. `/twilio-sms` exists and rejects unsigned requests with `403 Forbidden`, but no real Twilio Auth Token has been added and no public Caddy route should be enabled yet.

Hold SMS work until the user explicitly wants to resume it.

### Media request and search/import testing

Prowlarr, Radarr, Sonarr, qBittorrent, Gluetun, Byparr, Seerr, and the local SMS request bot are installed. The user has added working indexers in Prowlarr and configured Radarr/Sonarr quality profiles that allow 1080p fallback with 4K upgrades.

Current validated flow:

```text
SMS bot local test -> Seerr -> Radarr/Sonarr -> Prowlarr -> qBittorrent through Gluetun -> /mnt/storage/downloads -> /mnt/storage/media -> Jellyfin
```

Validated SMS request tests:

1. Movie search and request submission works through Seerr.
2. TV search works for season-specific requests.
3. TV season request confirmation works: the Silo season 2 test submitted to Seerr and added items to the Sonarr queue.
4. qBittorrent showed no new active download only because the queued Silo items were deleted manually from Sonarr before they could download.
5. `Status`, `Downloads`, and `Recently added` work locally.
6. SMS audit logging works locally.
7. SMS bot is tracked in the local monitoring/dashboard stack.
8. Keep SMS bot local/LAN-only until a real SMS provider ingress is intentionally designed.

### Media library maintenance

Periodic media cleanup should be run after large imports or when playback defaults look wrong.

Tasks:

1. Scan MKV files for cases where English audio exists but a non-English audio track is marked default.
2. Fix obvious cases with `mkvpropedit` after confirming track numbers.
3. Refresh Jellyfin metadata or rescan the affected library.
4. Keep this process documented in `docs/media-library-maintenance.md`.

## Immediate next step

### 1. Immich prep / photo-server planning

Purpose: prepare for self-hosted photo backup without rushing into a setup that could risk irreplaceable photos.

Before installing Immich:

1. Check current disk usage and available free space on `/mnt/storage`.
2. Decide where Immich library files should live, likely under `/mnt/storage/photos` or a dedicated `/mnt/storage/immich` tree.
3. Decide whether phone uploads will be the primary copy or just a backup copy.
4. Create a database-aware backup plan for Immich/Postgres before trusting it with real photos.
5. Keep Immich LAN-only at first.

### 2. Optional backup polish

Optional next backup improvements:

1. Add a Windows Scheduled Task for `D:\R515-Backups\pull-r515-backups.ps1`.
2. Add a second destination later, such as an external drive or cloud/object storage.
3. Consider stopping selected containers or using app-native database backups for more consistent archives.

## Next major tasks

### 3. Add Immich

Purpose: self-hosted photo backup and photo library.

Important before installing:

- Plan backup strategy before trusting it with irreplaceable photos.
- Immich changes quickly, so keep the stack documented and backed up.
- Do not expose publicly until authentication, backups, and updates are understood.

### 4. Monitor AdGuard Home

Current status:

- AdGuard Home is installed and working on `docker01`.
- DNS resolution from the Debian VM to `192.168.10.135:53` works.
- Blocking test works: `doubleclick.net` returns blocked addresses.
- Main/default UniFi LAN is now using `192.168.10.135` as DHCP DNS.
- iPhones may keep Limit IP Address Tracking / Private Relay enabled, accepting partial filtering on those devices.

Recommended approach:

1. Watch the AdGuard query log for new clients.
2. If something breaks, check the AdGuard query log and temporarily allow the blocked domain if needed.
3. Keep the router/gateway DNS rollback plan ready so the network can be reverted quickly.

### 5. Remote access redesign thought

It may be useful later to expose selected services through another DuckDNS name or another domain, but this should be treated as a separate remote-access design project.

Current direction:

- Keep Jellyfin public through `mediahubdaniel.duckdns.org` and Caddy.
- Keep admin apps LAN-only for now.
- Do not expose qBittorrent, Prowlarr, Radarr, Sonarr, Byparr, Portainer, Uptime Kuma admin, AdGuard Home, Homarr, Proxmox, Home Assistant, or the SMS bot webhook directly to the public internet.
- Prefer VPN/Tailscale/WireGuard-style access for private admin apps.
- Only consider extra DuckDNS/Caddy routes for carefully selected user-facing services, with authentication and logging planned first.

Possible future public-ish candidates:

```text
requests.<future-domain-or-duckdns> -> protected media request frontend
status.<future-domain-or-duckdns>   -> limited public status page, not the admin dashboard
```

Track details in `docs/domains.md` before implementing anything.

### 6. Finish Home Assistant migration

Home Assistant is currently in a safe paused state.

Current approach:

- Keep Raspberry Pi Home Assistant unchanged at `192.168.10.190` for now.
- Keep new HAOS VM at `192.168.10.127`.
- Do not move the new VM to `192.168.10.190` until the new VM is stable and the Pi fallback is no longer needed.
- Later decide whether to keep `192.168.10.127` permanently or move HAOS to `192.168.10.190`.

## Future project: SMS request and server-control assistant

Create a dedicated phone number that approved users can text to request media and interact with the home server.

Proposed request flow:

```text
SMS number
  -> custom request bot
  -> Seerr
  -> Radarr or Sonarr
  -> qBittorrent
  -> media folders
  -> Jellyfin
```

Example media commands:

```text
Movie Interstellar
TV Silo season 2
Status
What's downloading?
Recently added
```

The bot should:

- Accept requests only from approved phone numbers.
- Search for matching titles and ask for confirmation when results are ambiguous.
- Submit approved requests to Seerr.
- Reply with request, download, failure, and completion status.
- Avoid exposing administrative interfaces directly to the internet.

Possible future server and Home Assistant commands:

```text
Server status
Jellyfin status
UPS battery
Temperature
Wake gaming PC
Lights off
Garage status
```

Safety and permissions:

- Separate harmless status commands from administrative commands.
- Require stronger confirmation for reboots, shutdowns, garage control, locks, or other sensitive actions.
- Do not allow arbitrary shell commands over SMS.
- Keep an audit log of senders, commands, actions, and results.
- Use least-privilege API credentials for Jellyfin, Home Assistant, and request services.

Priority: connect a real SMS provider only after the user wants to resume that project and the Twilio/Auth Token/public webhook pieces are ready.

## Later possibilities

- Paperless-ngx for document archive
- Syncthing for folder sync
- Backup automation
- Off-server backup destination
- UPS monitoring
