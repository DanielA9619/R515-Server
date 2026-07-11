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

## Next major task

### 1. Home Assistant migration

Move Home Assistant from Raspberry Pi to a dedicated Home Assistant OS VM in Proxmox.

Recommended approach:

1. Create full backup on Raspberry Pi Home Assistant.
2. Download backup to PC.
3. Create HAOS VM in Proxmox.
4. Boot HAOS and restore full backup.
5. Keep Raspberry Pi powered off but untouched for a few days as fallback.

## Docker services to add after Home Assistant

### 2. Portainer

Purpose: easier Docker/container management.

Recommended access: local network only.

### 3. Uptime Kuma

Purpose: monitoring dashboard for Jellyfin, Caddy, Home Assistant, DuckDNS/domain, and other services.

Recommended access: local network only unless remote monitoring is intentionally configured later.

### 4. AdGuard Home

Purpose: network DNS filtering/ad blocking.

Notes:

- AdGuard Home is free and open-source.
- It can replace or compete with Pi-hole.
- Only one DNS/ad-blocking service should be primary at a time.

### 5. Immich

Purpose: self-hosted photo backup and photo library.

Important before installing:

- Plan backup strategy before trusting it with irreplaceable photos.
- Immich changes quickly, so keep the stack documented and backed up.
- Do not expose publicly until authentication, backups, and updates are understood.

### 6. qBittorrent

Purpose: downloads with access to the media server storage.

Recommended paths:

```text
/mnt/storage/downloads
/mnt/storage/media/movies
/mnt/storage/media/tv
```

Security note: qBittorrent web UI should stay local-only unless protected by VPN or another secure access method.

### 7. Jellyfin Quadro P400 transcoding

Purpose: use NVIDIA NVENC/NVDEC hardware acceleration for Jellyfin transcoding.

Needs:

- GPU visible to the Debian VM or passed through correctly
- NVIDIA driver in Debian VM
- NVIDIA Container Toolkit
- Docker Compose updated to expose the GPU to Jellyfin
- Jellyfin playback/transcoding settings configured

## Later possibilities

- Radarr
- Sonarr
- Prowlarr
- Overseerr/Jellyseerr
- Paperless-ngx for document archive
- Syncthing for folder sync
- Backup automation
- UPS monitoring
