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

## Immediate next step

### 1. Make a fresh post-GPU backup

Create and verify a new backup of the currently working Docker/Jellyfin/Caddy configuration before starting the next major service.

Recommended backup targets:

```text
/srv/docker
/etc/samba/smb.conf
```

Store the backup under:

```text
/mnt/storage/backups
```

A later improvement should copy backups off the R515 so they are not stored only on the same physical server.

## Next major task

### 2. Home Assistant migration

Move Home Assistant from the Raspberry Pi to a dedicated Home Assistant OS VM in Proxmox.

Current preferred approach because the existing installation is small and its backup has been unreliable:

1. Record or screenshot integrations, add-ons, dashboards, automations, scenes, scripts, helpers, and remote-access settings.
2. Create a fresh HAOS VM in Proxmox.
3. Use 2 CPU cores, 4 GB RAM, and a 64 GB disk.
4. Connect it to the bridged LAN.
5. Reserve its IP in UniFi.
6. Rebuild HACS, Matter Server, and UniFi Network manually.
7. Keep the Raspberry Pi unchanged until the VM has been tested for several days.

## Docker services to add after Home Assistant

### 3. Portainer

Purpose: easier Docker/container management.

Recommended access: local network only.

### 4. Uptime Kuma

Purpose: monitoring dashboard for Jellyfin, Caddy, Home Assistant, DuckDNS/domain, and other services.

Recommended access: local network only unless remote monitoring is intentionally configured later.

### 5. AdGuard Home

Purpose: network DNS filtering/ad blocking.

Notes:

- AdGuard Home is free and open-source.
- It can replace or compete with Pi-hole.
- Only one DNS/ad-blocking service should be primary at a time.

### 6. Immich

Purpose: self-hosted photo backup and photo library.

Important before installing:

- Plan backup strategy before trusting it with irreplaceable photos.
- Immich changes quickly, so keep the stack documented and backed up.
- Do not expose publicly until authentication, backups, and updates are understood.

### 7. Media automation stack

Planned services:

- qBittorrent
- Radarr
- Sonarr
- Prowlarr
- Jellyseerr or Overseerr

Purpose: allow approved movie and TV requests to be searched, downloaded, imported into the correct media folders, and detected by Jellyfin automatically.

Recommended paths:

```text
/mnt/storage/downloads
/mnt/storage/media/movies
/mnt/storage/media/tv
```

Security notes:

- Keep the qBittorrent web UI local-only unless protected by VPN or another secure access method.
- Use approved users and request limits in Jellyseerr/Overseerr.
- Add services one at a time and test each stage before continuing.

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

Likely implementation options:

- Twilio or another SMS API provider for the phone number and webhook.
- A small Python service running in Docker.
- Home Assistant REST/WebSocket API for approved smart-home actions.
- Jellyseerr/Overseerr API for media requests.

Priority: low. Build only after the core server, backups, Home Assistant, monitoring, and media automation stack are stable.

## Later possibilities

- Paperless-ngx for document archive
- Syncthing for folder sync
- Backup automation
- Off-server backup destination
- UPS monitoring
