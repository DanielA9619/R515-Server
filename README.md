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
- Byparr as an internal helper service on port `8191`
- Radarr for movie automation
- Sonarr for TV automation
- Seerr as the LAN-only media request frontend on port `5055`
- AdGuard Home for DNS filtering/ad blocking, now used by the main/default UniFi LAN via DHCP DNS
- Homarr as the central internal service dashboard / landing page

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
| VM | `docker01` | Debian VM for Docker, Jellyfin, Caddy, Samba, monitoring, DNS filtering, dashboard, and media automation |
| VM | `haos` | Home Assistant OS VM, currently kept separate while Raspberry Pi remains fallback |

## Current Docker Services

- Jellyfin
- Caddy
- Portainer
- Uptime Kuma
- Gluetun
- qBittorrent
- Prowlarr
- Byparr
- Radarr
- Sonarr
- Seerr
- AdGuard Home
- Homarr

Planned / pending Docker services:

- Immich
- Backup automation

## Documentation

- [`docs/current-config.md`](docs/current-config.md) — current known server configuration
- [`docs/roadmap.md`](docs/roadmap.md) — service build order and priorities
- [`docs/home-assistant-migration.md`](docs/home-assistant-migration.md) — HAOS VM migration plan
- [`docs/open-questions.md`](docs/open-questions.md) — info still needed
- [`docs/qbittorrent-vpn.md`](docs/qbittorrent-vpn.md) — qBittorrent + Mullvad/Gluetun setup notes
- [`docs/adguard-home.md`](docs/adguard-home.md) — AdGuard Home setup and rollout notes
- [`docs/service-dashboard.md`](docs/service-dashboard.md) — central service dashboard / landing page plan
- [`docs/byparr.md`](docs/byparr.md) — Byparr internal helper service notes
- [`docs/seerr.md`](docs/seerr.md) — Seerr media request frontend notes

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
- Homarr installed and configured with service cards for the main local apps
- Prowlarr DNS issue fixed by explicitly using AdGuard DNS (`192.168.10.135`) in Docker Compose
- Uptime Kuma DNS issue fixed so the public Jellyfin monitor can resolve `mediahubdaniel.duckdns.org`
- Byparr added as an internal helper service on port `8191`
- Prowlarr indexers added and confirmed working by the user
- Seerr installed as the LAN-only media request frontend on port `5055`
- Radarr and Sonarr quality profiles configured for 1080p fallback with 4K upgrades
- Fresh backup completed after qBittorrent + VPN setup
- Fresh backup completed after AdGuard Home whole-LAN rollout

## Current Priorities

1. Finish Seerr setup by testing one movie request and one TV request.
2. Confirm qBittorrent downloads land in `/mnt/storage/downloads` and Radarr/Sonarr import into the Jellyfin media folders.
3. Add Seerr to Homarr and Uptime Kuma.
4. Back up `/srv/docker` after Seerr/request testing works.
5. Build a safer backup plan, including off-server backups, before adding Immich.
6. Monitor AdGuard Home after whole-LAN DNS rollout and fix any breakage with targeted allowlist entries.
7. Finish Home Assistant migration only after the current VM is stable and the Raspberry Pi fallback is no longer needed.
8. Build the SMS request bot after Seerr and the core media request flow are stable.

## Important Safety Notes

- Do not commit DuckDNS tokens, passwords, API keys, Mullvad keys, or private keys.
- Do not expose Jellyfin port `8096` directly to the internet while Caddy is working.
- Public Jellyfin access should go through Caddy on ports `80` and `443` only.
- Keep qBittorrent, Prowlarr, Radarr, Sonarr, Byparr, Seerr, Portainer, Uptime Kuma, AdGuard Home, Homarr, and Home Assistant private/LAN-only unless remote access is intentionally redesigned.
- Keep qBittorrent behind Gluetun/Mullvad.
- Keep a DNS rollback plan ready: set UniFi DHCP DNS back to Auto or back to the previous resolver if AdGuard causes issues.
- Keep the central service dashboard internal/LAN-only unless remote access is redesigned with proper protection.
