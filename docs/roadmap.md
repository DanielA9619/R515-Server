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

Robocopy from Windows has copied the existing backup tree to the PC. The next check is to confirm that the newest SMS/audit backup files exist on the R515 and were copied to the PC, because the Windows listing did not clearly show every newest backup file.

Recommended next checks:

1. On Debian, run `date` to confirm the VM clock is correct.
2. On Debian, list `/mnt/storage/backups` and verify the latest `srv-docker-after-smsbot-audit-log.tar.gz` backup exists.
3. On Windows, rerun Robocopy after confirming the source backup files exist.
4. Later, turn the Robocopy command into a Windows Scheduled Task if this approach works well.

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
7. Keep SMS bot local/LAN-only until a real SMS provider ingress is intentionally designed.

### Media library maintenance

Periodic media cleanup should be run after large imports or when playback defaults look wrong.

Tasks:

1. Scan MKV files for cases where English audio exists but a non-English audio track is marked default.
2. Fix obvious cases with `mkvpropedit` after confirming track numbers.
3. Refresh Jellyfin metadata or rescan the affected library.
4. Keep this process documented in `docs/media-library-maintenance.md`.

## Immediate next step

### 1. Verify newest backups copied to the PC

The first Robocopy run copied existing backups to the PC, but the Windows listing should be checked against the R515 source tree.

Run on Debian:

```bash
date
find /mnt/storage/backups -type f -printf "%TY-%Tm-%Td %TH:%TM  %s bytes  %p\n" | sort
```

Then rerun the Windows Robocopy pull if the newest files are present on the server but missing from `D:\R515-Backups\backups`.

### 2. Add/confirm SMS bot monitoring/dashboard

Add or confirm the local SMS bot service in:

```text
Uptime Kuma -> http://192.168.10.135:5070/health
Homarr -> http://192.168.10.135:5070/health or an internal note/card for the SMS bot
```

The bot should remain LAN-only unless remote/SMS provider ingress is intentionally designed.

## Next major tasks

### 3. Improve backups

Current backups exist, and periodic manual Robocopy to the Windows PC has started. The next improvement is making the copy repeatable and adding a clear restore plan.

Recommended backup targets:

```text
/srv/docker
/etc/samba/smb.conf
Home Assistant backups
Important media/config metadata
```

Store source backups under:

```text
/mnt/storage/backups
```

Keep periodic PC copies under:

```text
D:\R515-Backups\backups
```

A later improvement should add a second destination, such as an external drive or cloud/object storage, especially before trusting Immich with irreplaceable photos.

### 4. Remote access redesign thought

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

### 5. Continue SMS request bot polish

Current status:

- Local FastAPI SMS bot is running on port `5070`.
- `/health` returns `{"status":"ok"}`.
- Movie search and request flow works through Seerr.
- Help command works.
- TV search and TV season request submission work through Seerr/Sonarr.
- `Status` reports Seerr/qBittorrent health, active/stalled/complete counts, and aggregate speed.
- `Downloads` reports not-yet-complete qBittorrent downloads and hides completed/seeding torrents.
- `Recently added` reports newest imported media from the read-only `/media` mount.
- Audit logging writes JSON-lines records under `/srv/docker/smsbot/data/audit.log`.

Next bot features:

1. Improve already-requested or already-available messages from Seerr.
2. Clean up `Recently added` title formatting if filesystem names are too messy.
3. Only after local behavior is stable, connect a real SMS provider/number.

### 6. Monitor AdGuard Home

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

### 7. Add Immich

Purpose: self-hosted photo backup and photo library.

Important before installing:

- Plan backup strategy before trusting it with irreplaceable photos.
- Immich changes quickly, so keep the stack documented and backed up.
- Do not expose publicly until authentication, backups, and updates are understood.

### 8. Finish Home Assistant migration

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

Priority: connect a real SMS provider only after the current local bot, backups, monitoring, and media automation are stable.

## Later possibilities

- Paperless-ngx for document archive
- Syncthing for folder sync
- Backup automation
- Off-server backup destination
- UPS monitoring
