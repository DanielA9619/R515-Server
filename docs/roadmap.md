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
- Home Assistant OS VM created in Proxmox
- New HAOS VM is reachable at `192.168.10.127`
- HACS, Matter Server, Terminal & SSH, Studio Code Server, Google Drive Backup, and UniFi work completed on new HAOS VM
- Home Assistant migration paused safely while Raspberry Pi remains fallback
- Portainer installed
- Uptime Kuma installed
- Uptime Kuma monitors added for key services
- qBittorrent installed
- Mullvad/Gluetun configured and confirmed healthy
- qBittorrent routed through Gluetun/Mullvad
- qBittorrent download paths configured
- qBittorrent monitor added in Uptime Kuma
- Fresh backup completed after qBittorrent + VPN was confirmed working
- Prowlarr installed
- Prowlarr authentication enabled
- qBittorrent added to Prowlarr as download client
- Radarr installed for movies
- Radarr authentication enabled
- Radarr root folder configured as `/movies`
- qBittorrent added to Radarr as download client using host `gluetun` and category `radarr`
- Prowlarr connected to Radarr
- Radarr monitor added in Uptime Kuma
- Sonarr installed for TV
- Sonarr authentication enabled
- Sonarr root folder configured as `/tv`
- qBittorrent added to Sonarr as download client using host `gluetun` and category `sonarr`
- Prowlarr connected to Sonarr
- Sonarr monitor added in Uptime Kuma

## Immediate next step

### 1. Configure and test indexers

Use Prowlarr to add legal/private indexers, then sync them to Radarr and Sonarr.

After indexers are added:

1. Test search inside Prowlarr.
2. Confirm Radarr sees synced indexers.
3. Confirm Sonarr sees synced indexers.
4. Run one small controlled Radarr movie test.
5. Run one small controlled Sonarr TV test.
6. Confirm qBittorrent downloads to `/mnt/storage/downloads`.
7. Confirm Radarr/Sonarr import completed files into Jellyfin folders.
8. Confirm Jellyfin sees the imported media after library scan.

Expected flow:

```text
Prowlarr -> Radarr/Sonarr -> qBittorrent through Gluetun -> /mnt/storage/downloads -> /mnt/storage/media -> Jellyfin
```

## Next major tasks

### 2. Add Jellyseerr or Overseerr

Purpose: provide a nicer request interface for movies and TV.

Recommended approach:

- Install only after Radarr/Sonarr/Prowlarr/qBittorrent are tested.
- Keep LAN-only at first.
- Connect it to Radarr and Sonarr.
- Later decide whether trusted users should get access.

### 3. Add AdGuard Home

Purpose: network DNS filtering/ad blocking.

Notes:

- AdGuard Home is free and open-source.
- It can replace or compete with Pi-hole.
- Only one DNS/ad-blocking service should be primary at a time.
- Do not change whole-network DNS until it has been tested from one device first.

### 4. Improve backups

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
  -> Jellyseerr/Overseerr
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
- Submit approved requests to Jellyseerr/Overseerr.
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

Priority: low. Build only after the core server, backups, Home Assistant, monitoring, and media automation stack are stable.

## Later possibilities

- Paperless-ngx for document archive
- Syncthing for folder sync
- Backup automation
- Off-server backup destination
- UPS monitoring
- Dashboard/homepage
