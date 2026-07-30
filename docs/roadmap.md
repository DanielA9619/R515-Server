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
- SMS bot `Status` command tested successfully against Seerr and qBittorrent
- SMS bot `Downloads` command tested successfully and adjusted to hide completed/seeding torrents
- SMS bot `Recently added` command tested successfully against the read-only `/media` mount
- AdGuard Home installed in Docker
- AdGuard Home dashboard reachable on the LAN
- AdGuard Home upstream DNS configured and server-side DNS tests passed
- AdGuard Home blocking confirmed with `doubleclick.net` resolving to `0.0.0.0` / `::`
- One iPhone was manually pointed to AdGuard DNS and appeared in the AdGuard query log after the correct DNS IP was used
- Main/default UniFi LAN DHCP DNS changed to `192.168.10.135`
- Whole-LAN AdGuard DNS rollout confirmed working by the user
- Fresh backup completed after AdGuard Home whole-LAN rollout
- Fresh backup completed after SMS bot status/downloads, Jellyfin plugin DNS, and media audio-default fixes

## Active validation

### Media request and search/import testing

Prowlarr, Radarr, Sonarr, qBittorrent, Gluetun, Byparr, Seerr, and the local SMS request bot are installed. The user has added working indexers in Prowlarr and configured Radarr/Sonarr quality profiles that allow 1080p fallback with 4K upgrades.

Current validated flow:

```text
SMS bot local test -> Seerr -> Radarr/Sonarr -> Prowlarr -> qBittorrent through Gluetun -> /mnt/storage/downloads -> /mnt/storage/media -> Jellyfin
```

Next controlled test flow:

1. Confirm TV request selection from the SMS bot submits correctly to Seerr.
2. Confirm Seerr sends the request to Sonarr.
3. Confirm Sonarr sends the download to qBittorrent through Gluetun.
4. Confirm qBittorrent downloads to `/mnt/storage/downloads`.
5. Confirm Sonarr imports the completed TV media into `/mnt/storage/media/tv`.
6. Confirm Jellyfin sees the TV media after a library scan.
7. Keep SMS bot local/LAN-only until a real SMS provider ingress is intentionally designed.

### Media library maintenance

Periodic media cleanup should be run after large imports or when playback defaults look wrong.

Tasks:

1. Scan MKV files for cases where English audio exists but a non-English audio track is marked default.
2. Fix obvious cases with `mkvpropedit` after confirming track numbers.
3. Refresh Jellyfin metadata or rescan the affected library.
4. Keep this process documented in `docs/media-library-maintenance.md`.

## Immediate next step

### 1. Add/confirm SMS bot monitoring/dashboard

Add or confirm the local SMS bot service in:

```text
Uptime Kuma -> http://192.168.10.135:5070/health
Homarr -> http://192.168.10.135:5070/health or an internal note/card for the SMS bot
```

The bot should remain LAN-only unless remote/SMS provider ingress is intentionally designed.

### 2. Continue SMS request bot polish

Next useful bot features:

1. Confirm TV request submission works end-to-end.
2. Improve already-requested or already-available messages from Seerr.
3. Add simple audit logging for sender, command, action, and result.
4. Clean up `Recently added` title formatting if filesystem names are too messy.
5. Only after local behavior is stable, connect a real SMS provider/number.
6. Back up `/srv/docker` after the `Recently added` checkpoint.

## Next major tasks

### 3. Improve backups

Current backups exist, but the next improvement is an actual repeatable backup plan.

Recommended backup targets:

```text
/srv/docker
/etc/samba/smb.conf
Home Assistant backups
Important media/config metadata
```

Store backups under:

```text
/mnt/storage/backups
```

A later improvement should copy backups off the R515 so they are not stored only on the same physical server.

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

### 5. Add Immich

Purpose: self-hosted photo backup and photo library.

Important before installing:

- Plan backup strategy before trusting it with irreplaceable photos.
- Immich changes quickly, so keep the stack documented and backed up.
- Do not expose publicly until authentication, backups, and updates are understood.

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

Priority: connect a real SMS provider only after the current local bot, backups, monitoring, and media automation are stable.

## Later possibilities

- Paperless-ngx for document archive
- Syncthing for folder sync
- Backup automation
- Off-server backup destination
- UPS monitoring
