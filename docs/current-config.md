# Current Configuration

Last refreshed after the September 2026 private-domain rollout and power-outage recovery work.

## Network

| Item | Current value |
| --- | --- |
| Gateway/router | `192.168.10.1` |
| Proxmox host | `192.168.10.50` |
| Debian Docker VM | `192.168.10.135` |
| Docker VM name | `docker01` |
| HAOS VM | `192.168.10.127` |
| Raspberry Pi HA fallback | `192.168.10.190` |
| Public Jellyfin | `https://mediahubdaniel.duckdns.org` |
| Private namespace | `*.r515.allenfamhouse.com` |

`docker01` uses a UniFi reservation at `192.168.10.135`.

## UniFi / WAN

WAN forwards currently required for public Jellyfin:

| WAN port | Protocol | Destination |
| --- | --- | --- |
| `80` | TCP | `192.168.10.135:80` |
| `443` | TCP | `192.168.10.135:443` |

Do not forward Jellyfin `8096`, Quick Links `8070`, qBittorrent `8080`, Portainer `9443`, Proxmox `8006`, AdGuard `3002`, Byparr `8191`, or the other private service ports publicly.

UniFi Teleport is the preferred private remote-access path.

## Planned Tailscale mesh

Status: **planned; not installed yet**.

Tailscale is planned as a second private management path alongside UniFi Teleport, not as a replacement for Mullvad and not as a replacement for the existing public Jellyfin path.

Planned uses:

- add the primary PC, phone, and an R515-side Tailscale endpoint to the same tailnet;
- allow direct private peer-to-peer access between those devices when possible;
- optionally advertise `192.168.10.0/24` from an R515-side subnet router so the PC/phone can reach LAN-only services such as Proxmox, Grafana, Portainer, Home Assistant, Radarr, Sonarr, and the other private R515 interfaces;
- provide a backup private-access path if UniFi Teleport is unavailable.

Jellyfin will remain on the current public Caddy path for now. qBittorrent will remain behind Gluetun/Mullvad. Tailscale will be kept separate from the qBittorrent VPN path.

The exact R515-side placement (Proxmox host, `docker01`, or a dedicated lightweight guest) should be decided before deployment based on the desired failure independence and subnet-routing role.

## AdGuard DNS

AdGuard Home runs on `docker01`:

```text
DNS:       192.168.10.135:53
Admin UI:  http://192.168.10.135:3002
Clean UI:  https://adguard.r515.allenfamhouse.com
```

Main/default LAN DHCP DNS points clients to `192.168.10.135`.

Private rewrites:

```text
*.r515.allenfamhouse.com -> 192.168.10.135
r515.allenfamhouse.com   -> 192.168.10.135
```

Byparr is an intentional exception for container-level public DNS. It uses:

```text
1.1.1.1
8.8.8.8
```

This prevents Byparr's browser/scraping functionality from depending on the local AdGuard instance being ready after a reboot or outage.

## Caddy

Caddy runs from Compose in `/srv/docker/docker-compose.yml` with:

```text
container: caddy
image:     caddy:latest
ports:     80/tcp, 443/tcp
config:    /srv/docker/caddy/Caddyfile -> /etc/caddy/Caddyfile
```

Caddy is launched with `admin off`, so configuration reloads use:

```bash
sudo docker kill --signal=USR1 caddy
```

Do not use `caddy reload` unless the admin endpoint is intentionally re-enabled.

### Private gate

Every private R515 hostname imports:

```caddyfile
(private_only) {
    @denied not remote_ip private_ranges
    abort @denied
}
```

The public Jellyfin hostname does not import this matcher.

### Important Caddy bind-mount note

The Caddyfile is a **single-file bind mount**. Avoid edits that replace the host file inode (for example `sed -i` or replacing it with `mv`) while the container is running, because the container can remain bound to the old inode.

Safe pattern:

1. build/validate a candidate file separately;
2. overwrite the live file contents in-place with `tee`;
3. validate from inside Caddy;
4. reload with `SIGUSR1`.

A stale inode issue was repaired by recreating only the Caddy Compose service. The host and container Caddyfile SHA-256 hashes were confirmed identical afterward.

## Private service URLs

| Service | Preferred URL | Direct fallback |
| --- | --- | --- |
| Quick Links | `https://links.r515.allenfamhouse.com` | `http://192.168.10.135:8070` |
| Homarr | `https://homarr.r515.allenfamhouse.com` | `http://192.168.10.135:7575` |
| Homarr legacy/base | `https://r515.allenfamhouse.com` | `http://192.168.10.135:7575` |
| Seerr | `https://seerr.r515.allenfamhouse.com` | `http://192.168.10.135:5055` |
| Radarr | `https://radarr.r515.allenfamhouse.com` | `http://192.168.10.135:7878` |
| Sonarr | `https://sonarr.r515.allenfamhouse.com` | `http://192.168.10.135:8989` |
| qBittorrent | `https://qbittorrent.r515.allenfamhouse.com` | `http://192.168.10.135:8080` |
| Uptime Kuma | `https://uptime.r515.allenfamhouse.com` | `http://192.168.10.135:3001` |
| Prowlarr | `https://prowlarr.r515.allenfamhouse.com` | `http://192.168.10.135:9696` |
| Portainer | `https://portainer.r515.allenfamhouse.com` | `https://192.168.10.135:9443` |
| AdGuard | `https://adguard.r515.allenfamhouse.com` | `http://192.168.10.135:3002` |
| Proxmox | `https://proxmox.r515.allenfamhouse.com` | `https://192.168.10.50:8006` |
| Home Assistant | `https://ha.r515.allenfamhouse.com` | `http://192.168.10.127:8123` |
| Jellyfin internal | `https://jellyfin.r515.allenfamhouse.com` | `http://192.168.10.135:8096` |

Public Jellyfin remains:

```text
https://mediahubdaniel.duckdns.org
```

## Verification checkpoint

September 2026 domain and outage-recovery results:

```text
Quick Links       working
Seerr             working
Radarr            working
Sonarr            working
qBittorrent       working; real storage bind verified after reboot
Uptime Kuma       working
Prowlarr          working; indexer Test All green after Byparr v5 fix
Byparr            /health HTTP 200 after direct public DNS fix
Portainer         working
AdGuard           working
Proxmox           working
Home Assistant    working after trusted-proxy configuration
Homarr            working
Jellyfin internal working
Jellyfin public   working
```

Caddy was also confirmed able to resolve and reach the Let's Encrypt ACME endpoint after the final reload.

## Docker services

Known active services include:

- `jellyfin`
- `caddy`
- `portainer`
- `uptime-kuma`
- `gluetun`
- `qbittorrent`
- `prowlarr`
- `byparr`
- `radarr`
- `sonarr`
- `seerr`
- `smsbot`
- `adguardhome`
- `homarr`
- `quicklinks`

Quick Links is currently a standalone `nginx:alpine` container rather than a Compose-managed service.

## Power-outage / reboot recovery

Two enabled systemd oneshot services protect the Docker stack from boot-order failures:

```text
r515-postboot-recovery.service
r515-byparr-recovery.service
```

Scripts:

```text
/usr/local/sbin/r515-postboot-recovery.sh
/usr/local/sbin/r515-byparr-recovery.sh
```

The main post-boot service waits for `/mnt/storage`, verifies it is writable, recreates storage-dependent containers against the real mount, waits for Gluetun, and recreates qBittorrent only after storage and VPN readiness.

The Byparr/Prowlarr v5 service runs afterward. It uses the real `/health` endpoint, recreates Byparr at most once per boot if needed, and restarts Prowlarr only after Byparr is functionally healthy.

Expected successful state for both units:

```text
active (exited)
status=0/SUCCESS
```

See [`power-outage-recovery.md`](power-outage-recovery.md) for the detailed failure history, validation results, and recovery commands.

## qBittorrent / VPN

qBittorrent uses Gluetun's network namespace:

```text
qBittorrent -> Gluetun -> Mullvad WireGuard -> Internet
```

The Caddy clean hostname proxies to:

```text
gluetun:8080
```

Downloads are bind-mounted from:

```text
/mnt/storage/downloads -> /downloads
```

After the September outage, qBittorrent torrents entered `Errored` state because Docker had started before the storage mount was ready. The post-boot recovery now recreates storage-dependent containers after `/mnt/storage` is confirmed mounted and writable.

Keep qBittorrent bound to the VPN interface and treat it as offline if Gluetun becomes unhealthy.

Do not commit Mullvad keys or `/srv/docker/.env` secret values.

## Byparr / Prowlarr

Byparr endpoint:

```text
http://192.168.10.135:8191
```

Current Compose DNS for Byparr:

```yaml
dns:
  - 1.1.1.1
  - 8.8.8.8
```

Functional health check:

```bash
curl -i --max-time 15 http://127.0.0.1:8191/health
```

Do not use `/docs` alone as proof that Byparr is healthy. During the outage recovery, `/docs` returned `200` while `/health` returned `502` with `NS_ERROR_UNKNOWN_HOST` because the browser layer could not resolve public sites.

See [`byparr.md`](byparr.md) for full recovery details.

## Quick Links

Quick Links content:

```text
/srv/docker/quicklinks/index.html
```

Container:

```text
name: quicklinks
image: nginx:alpine
host port: 8070
container port: 80
mount: /srv/docker/quicklinks -> /usr/share/nginx/html:ro
```

The live page is a polished responsive 12-card launcher and all cards now point to the clean private HTTPS hostnames.

The preferred clean URL has also been added to the iPhone Home Screen.

## Home Assistant

HAOS VM:

```text
VMID: 101
name: haos
IP:   192.168.10.127
```

Fresh VM setup includes HACS, Matter Server, Terminal & SSH, Studio Code Server, Google Drive Backup, and UniFi integration/add-on work.

The Raspberry Pi at `192.168.10.190` remains as fallback.

Caddy route is active and working:

```text
https://ha.r515.allenfamhouse.com
```

Working reverse-proxy configuration in `/config/configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.10.135
```

The setting was added through Studio Code Server, then Home Assistant configuration was validated and Home Assistant restarted successfully.

## Storage

Main storage is mounted at:

```text
/mnt/storage
```

Known folders include:

```text
/mnt/storage/media
/mnt/storage/media/movies
/mnt/storage/media/tv
/mnt/storage/media/music
/mnt/storage/photos
/mnt/storage/backups
/mnt/storage/downloads
/mnt/storage/shared
```

## Samba

Windows share:

```text
\\192.168.10.135\media
```

Share points to `/mnt/storage`.

## NVIDIA / Jellyfin transcoding

- NVIDIA Quadro P400 is passed through from Proxmox to `docker01`.
- NVIDIA drivers and Container Toolkit work in Debian.
- Jellyfin uses the NVIDIA runtime.
- Hardware transcoding was confirmed with Jellyfin ffmpeg appearing in `nvidia-smi` during a forced transcode.

## Backups

Backups are stored under:

```text
/mnt/storage/backups
```

A Windows pull workflow also copies server backups off the R515.

A fresh backup checkpoint was completed after the private-domain and Home Assistant reverse-proxy work.

## Pending media notifications

Status: **planned; not installed yet**.

The planned media-notification layer will use a separate ntfy topic from the critical R515 alert topic so routine media events do not bury infrastructure alerts.

Planned sources:

- Seerr request events;
- Radarr grab/import/failure events;
- Sonarr grab/import/failure events;
- qBittorrent completion notifications only if they add useful information beyond Radarr/Sonarr import events.

Notification formatting for the existing infrastructure alerts should also be cleaned up so phone notifications emphasize a short title and useful description rather than raw Alertmanager/Healthchecks metadata.

## Safety

- Never commit passwords, API keys, DuckDNS tokens, Mullvad keys, webhook tokens, or private keys.
- Keep private R515 service hostnames LAN/UniFi Teleport only.
- Keep the Caddy `private_only` gate on all private `r515` sites.
- Keep qBittorrent behind Gluetun/Mullvad.
- Keep Byparr port `8191` private/LAN-only.
- Keep a DNS rollback plan for AdGuard.
