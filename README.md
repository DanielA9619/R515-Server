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
- NVIDIA Quadro P400 passthrough for Jellyfin hardware transcoding
- Home Assistant OS VM in Proxmox, currently paused/safe while Raspberry Pi remains as fallback
- Portainer for Docker management
- Uptime Kuma for monitoring
- qBittorrent routed through Gluetun/Mullvad
- Prowlarr for indexer management
- Radarr for movie automation
- Sonarr for TV automation
- AdGuard Home for DNS filtering/ad blocking, now used by the main/default UniFi LAN via DHCP DNS

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
| HAOS VM | `192.168.10.127` |
| Raspberry Pi Home Assistant fallback | `192.168.10.190` |
| Jellyfin Domain | `mediahubdaniel.duckdns.org` |
| DuckDNS public IP observed during setup | `166.70.251.126` |

`192.168.10.135` is reserved in UniFi for the Debian Docker VM.

## Hardware

- Dell PowerEdge R515
- Proxmox installed on system SSD
- 3TB HDD attached to the Debian VM and mounted at `/mnt/storage`
- NVIDIA Quadro P400 passed through to `docker01`
- PCIe riser slot was cut open-ended so the P400 physically fits

## Virtualization Layout

| Layer | Name | Purpose |
|---|---|---|
| Bare metal | Dell PowerEdge R515 | Physical server |
| Hypervisor | Proxmox | VM host |
| VM | `docker01` | Debian VM for Docker, Jellyfin, Caddy, Samba, monitoring, DNS filtering, and media automation |
| VM | `haos` | Home Assistant OS VM, currently kept separate while Raspberry Pi remains fallback |

## Current Docker Services

- Jellyfin
- Caddy
- Portainer
- Uptime Kuma
- Gluetun
- qBittorrent
- Prowlarr
- Radarr
- Sonarr
- AdGuard Home

Planned / pending Docker services:

- Homarr or similar central service dashboard
- Immich
- Jellyseerr or Overseerr
- Backup automation

## Documentation

- [`docs/current-config.md`](docs/current-config.md) — current known server configuration
- [`docs/roadmap.md`](docs/roadmap.md) — service build order and priorities
- [`docs/home-assistant-migration.md`](docs/home-assistant-migration.md) — HAOS VM migration plan
- [`docs/open-questions.md`](docs/open-questions.md) — info still needed
- [`docs/qbittorrent-vpn.md`](docs/qbittorrent-vpn.md) — qBittorrent + Mullvad/Gluetun setup notes
- [`docs/adguard-home.md`](docs/adguard-home.md) — AdGuard Home setup and rollout notes
- [`docs/service-dashboard.md`](docs/service-dashboard.md) — central service dashboard / landing page plan

## Completed Major Milestones

- Jellyfin local and remote access working through Caddy
- Samba share working from Windows to `/mnt/storage`
- Quadro P400 passthrough complete
- Jellyfin hardware transcoding confirmed
- Portainer installed
- Uptime Kuma installed with monitors
- qBittorrent installed and routed through Gluetun/Mullvad
- Prowlarr installed and connected to qBittorrent
- Radarr installed and connected to qBittorrent/Prowlarr
- Sonarr installed and connected to qBittorrent/Prowlarr
- AdGuard Home installed, verified, and rolled out to the main/default UniFi LAN DNS
- Fresh backup completed after qBittorrent + VPN setup
- Fresh backup completed after AdGuard Home whole-LAN rollout

## Current Priorities

1. Add a central internal service dashboard so local service links are in one place.
2. Monitor AdGuard Home after whole-LAN DNS rollout and fix any breakage with targeted allowlist entries.
3. Build a safer backup plan, including off-server backups.
4. Pause Prowlarr indexer/tracker testing until legal/private trackers are available.
5. Add Jellyseerr or Overseerr after indexers are available and Radarr/Sonarr search/import has been tested.
6. Add Immich for photo backup and management after backups are ready.
7. Finish Home Assistant migration only after the current VM is stable and the Raspberry Pi fallback is no longer needed.

## Important Safety Notes

- Do not commit DuckDNS tokens, passwords, API keys, Mullvad keys, or private keys.
- Do not expose Jellyfin port `8096` directly to the internet while Caddy is working.
- Public Jellyfin access should go through Caddy on ports `80` and `443` only.
- Keep qBittorrent, Prowlarr, Radarr, Sonarr, Portainer, Uptime Kuma, AdGuard Home, and Home Assistant private/LAN-only unless remote access is intentionally redesigned.
- Keep qBittorrent behind Gluetun/Mullvad.
- Keep a DNS rollback plan ready: set UniFi DHCP DNS back to Auto or back to the previous resolver if AdGuard causes issues.
- Keep the central service dashboard internal/LAN-only unless remote access is redesigned with proper protection.