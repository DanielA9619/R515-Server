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
- Local SMS request bot on port `5070`
- AdGuard Home for DNS filtering/ad blocking, now used by the main/default UniFi LAN via DHCP DNS
- Homarr as the central internal service dashboard / landing page

Jellyfin works locally and remotely through:

```text
https://mediahubdaniel.duckdns.org
```

## Quick Access URLs

| Service | URL | Notes |
|---|---|---|
| Homarr dashboard | `https://r515.allenfamhouse.com` | Preferred LAN landing page. Uses Caddy internal TLS, so browser trust warnings are expected unless the internal CA is trusted. |
| Homarr direct | `http://192.168.10.135:7575` | Direct LAN access. |
| Jellyfin public | `https://mediahubdaniel.duckdns.org` | Only public service currently intended to be exposed through Caddy. |
| Jellyfin local | `http://192.168.10.135:8096` | LAN-only direct access. |
| Uptime Kuma | `http://192.168.10.135:3001` | LAN-only monitoring dashboard. |
| Uptime Kuma status page | `http://192.168.10.135:3001/status/r515` | LAN-only status page. |
| Portainer | `https://192.168.10.135:9443` | LAN/VPN-only admin service. |
| Seerr | `http://192.168.10.135:5055` | LAN-only media request frontend. |
| qBittorrent | `http://192.168.10.135:8080` | LAN-only; traffic routes through Gluetun/Mullvad. |
| Prowlarr | `http://192.168.10.135:9696` | LAN-only. |
| Radarr | `http://192.168.10.135:7878` | LAN-only. |
| Sonarr | `http://192.168.10.135:8989` | LAN-only. |
| AdGuard Home | `http://192.168.10.135:3002` | LAN-only DNS/ad-blocking admin UI. |
| Byparr | `http://192.168.10.135:8191` | LAN-only helper service. |
| SMS bot health | `http://192.168.10.135:5070/health` | LAN-only monitor endpoint; Twilio work is paused. |
| Home Assistant VM | `http://192.168.10.127:8123` | New HAOS VM, still separate while Pi fallback remains. |
| Proxmox | `https://192.168.10.50:8006` | LAN/VPN-only hypervisor admin. |
| Samba share | `\\192.168.10.135\media` | Windows file share to `/mnt/storage`. |
| Backup pull script on Windows | `D:\R515-Backups\pull-r515-backups.ps1` | Pulls `/mnt/storage/backups` to the PC with Robocopy. |

Remote access note: UniFi Teleport currently works for private remote access. Keep admin services LAN/VPN-only; do not expose them directly through DuckDNS/Caddy.

## Network

| Device / Service | IP / Address |
|---|---|
| Gateway / Router | `192.168.10.1` |
| Proxmox Host | `192.168.10.50` |
| Debian Docker VM `docker01` | `192.168.10.135` |
| HAOS VM | `192.168.10.127` |
| Raspberry Pi Home Assistant fallback | `192.168.10.190` |
| Jellyfin Domain | `mediahubdaniel.duckdns.org` |
| Homarr / central dashboard domain | `r515.allenfamhouse.com` |
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
| VM | `docker01` | Debian VM for Docker, Jellyfin, Caddy, Samba, monitoring, DNS filtering, dashboard, media automation, and local SMS bot testing |
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
- SMS Bot
- AdGuard Home
- Homarr

Planned / pending Docker services:

- Immich
- Backup automation
- Tdarr test-only media optimization

Possible tooling / non-service additions:

- Wireshark on a workstation or temporary admin VM for packet captures and network troubleshooting

## Documentation

- [`docs/current-config.md`](docs/current-config.md) — current known server configuration
- [`docs/domains.md`](docs/domains.md) — service domains, internal DNS names, and local URLs
- [`docs/media-request-workflow.md`](docs/media-request-workflow.md) — streamlined movie/TV request workflow and search troubleshooting plan
- [`docs/media-library-maintenance.md`](docs/media-library-maintenance.md) — periodic Jellyfin/media cleanup checks, including audio default flags
- [`docs/sms-bot.md`](docs/sms-bot.md) — local SMS request bot setup, commands, tests, and safety notes
- [`docs/roadmap.md`](docs/roadmap.md) — service build order and priorities
- [`docs/home-assistant-migration.md`](docs/home-assistant-migration.md) — HAOS VM migration plan
- [`docs/open-questions.md`](docs/open-questions.md) — info still needed
- [`docs/qbittorrent-vpn.md`](docs/qbittorrent-vpn.md) — qBittorrent + Mullvad/Gluetun setup notes
- [`docs/adguard-home.md`](docs/adguard-home.md) — AdGuard Home setup and rollout notes
- [`docs/service-dashboard.md`](docs/service-dashboard.md) — central service dashboard / landing page plan
- [`docs/byparr.md`](docs/byparr.md) — Byparr internal helper service notes and recovery procedure
- [`docs/seerr.md`](docs/seerr.md) — Seerr media request frontend notes
- [`docs/windows-backup-pull.md`](docs/windows-backup-pull.md) — Windows Robocopy backup pull script
- [`docs/server-backup-creation.md`](docs/server-backup-creation.md) — Debian-side backup creation script
- [`docs/restore-procedure.md`](docs/restore-procedure.md) — restore-read test and emergency restore outline

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
- Jellyfin plugin catalog DNS issue fixed by explicitly using AdGuard DNS (`192.168.10.135`) in Docker Compose
- Byparr added as an internal helper service on port `8191`
- Byparr hard-recreate recovery documented after a 500/Internal Server Error issue was fixed
- Prowlarr indexers added and confirmed working by the user
- Seerr installed as the LAN-only media request frontend on port `5055`
- Seerr connected to Jellyfin, Radarr, and Sonarr
- Seerr request flow tested by the user
- Seerr Uptime Kuma monitor URL typo fixed to use port `5055`
- Radarr and Sonarr quality profiles configured for 1080p fallback with 4K upgrades
- qBittorrent stalled-torrent issue fixed by binding qBittorrent to the correct VPN interface
- Initial movie audio-default cleanup completed for files where Russian was default and English was available
- Local SMS request bot installed on port `5070`
- SMS bot movie search/request, TV search, help, status, downloads, and recently-added commands tested locally
- SMS bot added/ready for Uptime Kuma and Homarr local tracking
- SMS/Twilio preparation paused safely: `/twilio-sms` exists and rejects unsigned requests, but no Twilio token or public route is active
- Debian-side backup script installed and tested
- Windows Robocopy backup pull script installed and tested with progress/ETA output
- Restore-read test passed without overwriting live files
- Fresh backup completed after qBittorrent + VPN setup
- Fresh backup completed after AdGuard Home whole-LAN rollout
- Fresh backup completed after SMS bot status/downloads, Jellyfin plugin DNS, and media audio-default fixes

## Current Priorities

1. Streamline media request workflow: use Homarr as the daily launchpad, Seerr as the normal request UI, and Radarr/Sonarr only for advanced interactive search.
2. Decide next tooling direction: Tdarr test-only media optimization, Wireshark troubleshooting workflow, Home Assistant migration, or Immich prep.
3. Keep using the backup rhythm: create a Debian-side config backup, then pull it to the Windows PC.
4. Run periodic media library maintenance checks for audio default flags and Jellyfin/plugin connectivity.
5. Monitor AdGuard Home after whole-LAN DNS rollout and fix any breakage with targeted allowlist entries.
6. Finish Home Assistant migration only after the current VM is stable and the Raspberry Pi fallback is no longer needed.
7. Keep SMS/Twilio paused until intentionally resumed.

## Important Safety Notes

- Do not commit DuckDNS tokens, passwords, API keys, Mullvad keys, SMS provider secrets, webhook tokens, or private keys.
- Do not expose Jellyfin port `8096` directly to the internet while Caddy is working.
- Public Jellyfin access should go through Caddy on ports `80` and `443` only.
- Keep qBittorrent, Prowlarr, Radarr, Sonarr, Byparr, Seerr, SMS bot, Portainer, Uptime Kuma, AdGuard Home, Homarr, and Home Assistant private/LAN-only unless remote access is intentionally redesigned.
- Keep qBittorrent behind Gluetun/Mullvad.
- Keep a DNS rollback plan ready: set UniFi DHCP DNS back to Auto or back to the previous resolver if AdGuard causes issues.
- Keep the central service dashboard internal/LAN-only unless remote access is redesigned with proper protection.
