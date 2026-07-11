# Dell PowerEdge R515 Home Server

This repo documents Daniel's Dell PowerEdge R515 Proxmox home server build.

## Current Status

The server is live and currently running:

- Proxmox on the R515
- Debian Docker VM named `docker01`
- Jellyfin in Docker
- Caddy reverse proxy in Docker
- Samba file share from Debian to Windows
- DuckDNS updater on Debian

Jellyfin works locally and remotely through:

```text
https://mediahubdaniel.duckdns.org
```

## Network

| Device / Service | IP / Address |
|---|---|
| Gateway / Router | `192.168.10.1` |
| Proxmox Host | `192.168.10.50` |
| Debian Docker VM `docker01` | `192.168.10.135` |
| Jellyfin Domain | `mediahubdaniel.duckdns.org` |
| Current DuckDNS-resolved public IP | `166.70.251.126` |

`192.168.10.135` is reserved in UniFi for the Debian Docker VM.

## Hardware

- Dell PowerEdge R515
- Proxmox installed on system SSD
- 3TB HDD attached to the Debian VM as `/dev/sdb`
- NVIDIA Quadro P400 detected by the system
- PCIe riser slot was cut open-ended so the P400 physically fits

## Virtualization Layout

| Layer | Name | Purpose |
|---|---|---|
| Bare metal | Dell PowerEdge R515 | Physical server |
| Hypervisor | Proxmox | VM host |
| VM | `docker01` | Debian VM for Docker, Jellyfin, Caddy, Samba, future services |
| Future VM | HAOS VM | Home Assistant OS migration target |

## Current Docker Services

- Jellyfin
- Caddy

Planned Docker services:

- Portainer
- Uptime Kuma
- AdGuard Home
- Immich
- qBittorrent
- Possibly Radarr / Sonarr / Prowlarr later

## Current Priorities

1. Migrate Home Assistant from Raspberry Pi to a dedicated HAOS VM.
2. Add Portainer for Docker management.
3. Add Uptime Kuma for monitoring.
4. Add AdGuard Home for DNS/ad blocking.
5. Add Immich for photo backup and management.
6. Add qBittorrent with access to the Jellyfin media storage.
7. Configure Quadro P400 hardware transcoding for Jellyfin.

## Important Safety Notes

- Do not commit DuckDNS tokens, passwords, API keys, or private keys.
- Do not expose Jellyfin port `8096` directly to the internet while Caddy is working.
- Public access should go through Caddy on ports `80` and `443` only.
- Keep Home Assistant and admin dashboards private unless there is a specific reason to expose them.
