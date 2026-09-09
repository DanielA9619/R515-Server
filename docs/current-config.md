# Current Configuration

Last refreshed after the private R515 domain/Caddy rollout in September 2026.

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

Do not forward Jellyfin `8096`, Quick Links `8070`, qBittorrent `8080`, Portainer `9443`, Proxmox `8006`, AdGuard `3002`, or the other private service ports publicly.

UniFi Teleport is the preferred private remote-access path.

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

September 2026 Caddy/domain rollout results:

```text
Quick Links       working
Seerr             working
Radarr            working
Sonarr            working
qBittorrent       working
Uptime Kuma       working
Prowlarr          working
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

## qBittorrent / VPN

qBittorrent uses Gluetun's network namespace:

```text
qBittorrent -> Gluetun -> Mullvad WireGuard -> Internet
```

The Caddy clean hostname proxies to:

```text
gluetun:8080
```

Keep qBittorrent bound to the VPN interface and treat it as offline if Gluetun becomes unhealthy.

Do not commit Mullvad keys or `/srv/docker/.env` secret values.

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

Create a fresh Docker/config backup and Home Assistant backup after the completed domain/reverse-proxy rollout.

## Safety

- Never commit passwords, API keys, DuckDNS tokens, Mullvad keys, webhook tokens, or private keys.
- Keep private R515 service hostnames LAN/UniFi Teleport only.
- Keep the Caddy `private_only` gate on all private `r515` sites.
- Keep qBittorrent behind Gluetun/Mullvad.
- Keep a DNS rollback plan for AdGuard.
