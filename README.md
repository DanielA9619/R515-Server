# Dell PowerEdge R515 Home Server

This repo documents Daniel's Dell PowerEdge R515 Proxmox home server build.

## Current Status

The server is live and currently running:

- Proxmox on the R515
- Debian Docker VM `docker01`
- Jellyfin with NVIDIA Quadro P400 hardware transcoding
- Caddy reverse proxy
- Samba media share
- DuckDNS updater
- Home Assistant OS VM on Proxmox, with the Raspberry Pi still retained as fallback
- Portainer
- Uptime Kuma
- qBittorrent behind Gluetun/Mullvad
- Prowlarr
- Byparr
- Radarr
- Sonarr
- Seerr
- local SMS request bot (provider/Twilio work paused)
- AdGuard Home as main-LAN DNS
- Homarr desktop dashboard
- Quick Links mobile launcher
- automatic post-boot storage/service recovery for outage/reboot handling

## Public Service

Jellyfin is the only service intentionally exposed publicly:

```text
https://mediahubdaniel.duckdns.org
```

Ports `80` and `443` on the WAN are forwarded to Caddy. Jellyfin port `8096` is not exposed directly.

## Private R515 Domains

AdGuard provides the private wildcard DNS rewrite:

```text
*.r515.allenfamhouse.com -> 192.168.10.135
r515.allenfamhouse.com   -> 192.168.10.135
```

Caddy serves the private hostnames with internal TLS and an explicit `private_only` source-IP gate. These names are intended for the home LAN and UniFi Teleport, not public access.

## Quick Access URLs

| Service | Preferred URL | Notes |
| --- | --- | --- |
| Quick Links | `https://links.r515.allenfamhouse.com` | Preferred mobile launcher; LAN / Teleport only. |
| Homarr | `https://homarr.r515.allenfamhouse.com` | Preferred desktop dashboard. |
| Homarr legacy/base | `https://r515.allenfamhouse.com` | Existing Homarr alias. |
| Seerr | `https://seerr.r515.allenfamhouse.com` | Normal movie/TV request UI. |
| Radarr | `https://radarr.r515.allenfamhouse.com` | Advanced movie management. |
| Sonarr | `https://sonarr.r515.allenfamhouse.com` | Advanced TV management. |
| qBittorrent | `https://qbittorrent.r515.allenfamhouse.com` | Web UI; traffic remains behind Gluetun/Mullvad. |
| Uptime Kuma | `https://uptime.r515.allenfamhouse.com` | Monitoring dashboard. |
| Prowlarr | `https://prowlarr.r515.allenfamhouse.com` | Indexer management. |
| Portainer | `https://portainer.r515.allenfamhouse.com` | Docker admin. |
| AdGuard Home | `https://adguard.r515.allenfamhouse.com` | DNS/admin UI. |
| Proxmox | `https://proxmox.r515.allenfamhouse.com` | Hypervisor admin. |
| Home Assistant | `https://ha.r515.allenfamhouse.com` | Working through Caddy; LAN / Teleport only. |
| Jellyfin internal | `https://jellyfin.r515.allenfamhouse.com` | Private LAN/Teleport alias. |
| Jellyfin public | `https://mediahubdaniel.duckdns.org` | Public Caddy route. |

Direct/raw fallbacks remain available when troubleshooting:

| Service | Direct URL |
| --- | --- |
| Quick Links | `http://192.168.10.135:8070` |
| Homarr | `http://192.168.10.135:7575` |
| Seerr | `http://192.168.10.135:5055` |
| Radarr | `http://192.168.10.135:7878` |
| Sonarr | `http://192.168.10.135:8989` |
| qBittorrent | `http://192.168.10.135:8080` |
| Uptime Kuma | `http://192.168.10.135:3001` |
| Prowlarr | `http://192.168.10.135:9696` |
| Portainer | `https://192.168.10.135:9443` |
| AdGuard Home | `http://192.168.10.135:3002` |
| Proxmox | `https://192.168.10.50:8006` |
| Home Assistant | `http://192.168.10.127:8123` |
| Jellyfin | `http://192.168.10.135:8096` |
| Byparr | `http://192.168.10.135:8191` |
| SMS bot health | `http://192.168.10.135:5070/health` |

Remote access note: UniFi Teleport is the normal private remote path for these internal services.

## Network

| Device / Service | IP / Address |
| --- | --- |
| Gateway / Router | `192.168.10.1` |
| Proxmox Host | `192.168.10.50` |
| Debian Docker VM `docker01` | `192.168.10.135` |
| HAOS VM | `192.168.10.127` |
| Raspberry Pi Home Assistant fallback | `192.168.10.190` |
| Public Jellyfin domain | `mediahubdaniel.duckdns.org` |
| Private R515 namespace | `*.r515.allenfamhouse.com` |

`192.168.10.135` is reserved in UniFi for `docker01`.

## Hardware

- Dell PowerEdge R515
- Proxmox on system SSD
- 3 TB HDD attached to Debian and mounted at `/mnt/storage`
- NVIDIA Quadro P400 passed through to `docker01`
- PCIe riser slot physically opened so the P400 fits

## Virtualization Layout

| Layer | Name | Purpose |
| --- | --- | --- |
| Bare metal | Dell PowerEdge R515 | Physical server |
| Hypervisor | Proxmox | VM host |
| VM | `docker01` | Debian VM for Docker, Jellyfin, Caddy, Samba, monitoring, DNS, dashboards, and media automation |
| VM | `haos` | Dedicated Home Assistant OS VM |

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
- Quick Links (`quicklinks`, standalone `nginx:alpine` container)

Planned / pending:

- Immich
- additional backup automation
- optional Tdarr test-only media optimization

## Quick Links

Quick Links is the preferred mobile launcher. The current page is a polished responsive 12-card page with clean private HTTPS links for Seerr, Radarr, Sonarr, qBittorrent, Uptime Kuma, Jellyfin, Prowlarr, Portainer, AdGuard, Proxmox, Home Assistant, and Homarr.

Preferred URL:

```text
https://links.r515.allenfamhouse.com
```

The clean Quick Links URL has also been added to the iPhone Home Screen.

## Caddy Private-Only Design

Because public Jellyfin requires WAN `443` to reach Caddy, private DNS alone is not sufficient to protect internal services. Private R515 sites import:

```caddyfile
(private_only) {
    @denied not remote_ip private_ranges
    abort @denied
}
```

The public `mediahubdaniel.duckdns.org` site does not import this matcher.

A stale single-file Caddy bind-mount issue was repaired by recreating only the Caddy Compose service. The host and mounted container Caddyfile hashes were confirmed identical afterward.

## Power-Outage / Reboot Recovery

A September 2026 power outage exposed a real boot-order problem: `/mnt/storage` could mount after Docker had already started storage-dependent containers. qBittorrent then saw the wrong underlying directory and torrents entered `Errored` state.

The final recovery design uses two enabled systemd oneshot services:

```text
r515-postboot-recovery.service
r515-byparr-recovery.service
```

The main recovery waits for `/mnt/storage`, confirms it is writable, recreates storage-dependent containers against the real mount, waits for Gluetun, and then recreates qBittorrent.

Byparr also exposed a separate DNS/readiness issue after reboot. Its `/docs` page could return `200` while its browser layer failed public DNS with `NS_ERROR_UNKNOWN_HOST`. Byparr now uses direct public DNS:

```yaml
dns:
  - 1.1.1.1
  - 8.8.8.8
```

The final v5 Byparr/Prowlarr recovery checks the real `/health` endpoint, recreates Byparr at most once per boot if needed, and only restarts Prowlarr after Byparr is functionally healthy.

Validated final state:

```text
/mnt/storage                    mounted read/write
main post-boot recovery         active (exited), SUCCESS
Byparr/Prowlarr recovery v5     active (exited), SUCCESS
qBittorrent                     real storage bind verified
Gluetun                         healthy
Byparr /health                  HTTP 200
Prowlarr indexer Test All       all green
Jellyfin                        healthy
Quick Links                     HTTP 200
Internal Jellyfin               HTTP 302
Public Jellyfin                 HTTP 302
```

See [`docs/power-outage-recovery.md`](docs/power-outage-recovery.md) for the full root-cause history and recovery commands.

## Verification Checkpoint — September 2026

The internal-domain rollout is complete. The clean private URLs for Quick Links, Seerr, Radarr, Sonarr, qBittorrent, Uptime Kuma, Prowlarr, Portainer, AdGuard, Proxmox, Homarr, Home Assistant, and Jellyfin are working through Caddy on LAN / UniFi Teleport.

Public Jellyfin and the private service routes were revalidated after the controlled reboot/outage-recovery work.

## Home Assistant Reverse Proxy

Home Assistant initially returned HTTP `400` through Caddy until reverse-proxy trust was added to `/config/configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.10.135
```

The file was edited through Studio Code Server, Home Assistant configuration was validated, and Home Assistant was restarted. The clean URL now works:

```text
https://ha.r515.allenfamhouse.com
```

## Documentation

- [`docs/current-config.md`](docs/current-config.md) — current known server configuration
- [`docs/power-outage-recovery.md`](docs/power-outage-recovery.md) — validated boot/outage recovery, root causes, and troubleshooting
- [`docs/domains.md`](docs/domains.md) — active public/private domains, internal DNS, and Caddy private routing
- [`docs/quicklinks.md`](docs/quicklinks.md) — mobile Quick Links launcher
- [`docs/service-dashboard.md`](docs/service-dashboard.md) — Homarr desktop + Quick Links mobile dashboard strategy
- [`docs/media-request-workflow.md`](docs/media-request-workflow.md) — media request workflow
- [`docs/qbittorrent-vpn.md`](docs/qbittorrent-vpn.md) — qBittorrent + Gluetun/Mullvad
- [`docs/adguard-home.md`](docs/adguard-home.md) — AdGuard Home and internal wildcard DNS
- [`docs/home-assistant-migration.md`](docs/home-assistant-migration.md) — HAOS VM migration/status
- [`docs/media-library-maintenance.md`](docs/media-library-maintenance.md) — media cleanup checks
- [`docs/sms-bot.md`](docs/sms-bot.md) — local SMS request bot
- [`docs/byparr.md`](docs/byparr.md) — Byparr DNS, health, and recovery details
- [`docs/seerr.md`](docs/seerr.md) — Seerr notes
- [`docs/windows-backup-pull.md`](docs/windows-backup-pull.md) — Windows backup pull
- [`docs/server-backup-creation.md`](docs/server-backup-creation.md) — Debian-side backup creation
- [`docs/restore-procedure.md`](docs/restore-procedure.md) — restore procedure
- [`docs/roadmap.md`](docs/roadmap.md) — roadmap/priorities
- [`docs/open-questions.md`](docs/open-questions.md) — remaining questions

## Current Priorities

1. Leave the now-stable outage-recovery stack running and monitor normal behavior rather than repeatedly rebooting it.
2. Add one R515 button in Home Assistant that opens `https://links.r515.allenfamhouse.com` if still desired.
3. Verify the HAOS VM's devices/integrations and keep the Raspberry Pi fallback untouched until the VM has proven stable.
4. Continue normal media-library, AdGuard, and Prowlarr/Byparr monitoring.
5. Plan the next major service/tooling step, with Immich as the leading candidate; design storage and backup architecture before deployment.

## Important Safety Notes

- Never commit DuckDNS tokens, passwords, API keys, Mullvad keys, SMS provider secrets, webhook tokens, or private keys.
- Keep qBittorrent, Prowlarr, Radarr, Sonarr, Byparr, Seerr, Portainer, Uptime Kuma, AdGuard Home, Homarr, Proxmox, Home Assistant, Quick Links, and the internal Jellyfin alias private/LAN/Teleport-only.
- Do not remove the Caddy `private_only` gate from private R515 sites.
- Keep qBittorrent behind Gluetun/Mullvad.
- Keep Byparr port `8191` private; direct public DNS is outbound-only and does not change exposure.
- Keep a DNS rollback plan available if AdGuard causes problems.
