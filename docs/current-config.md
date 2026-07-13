# Current Configuration

Last updated from chat notes during the R515 setup.

## Network

| Item | Current value |
| --- | --- |
| Gateway/router | `192.168.10.1` |
| Proxmox host | `192.168.10.50` |
| Debian Docker VM | `192.168.10.135` |
| VM name | `docker01` |
| Jellyfin public domain | `mediahubdaniel.duckdns.org` |
| DuckDNS public IP observed during setup | `166.70.251.126` |

## UniFi port forwards

| WAN port | Protocol | Destination |
| --- | --- | --- |
| `80` | TCP | `192.168.10.135:80` |
| `443` | TCP | `192.168.10.135:443` |

Do not forward Jellyfin `8096` publicly while Caddy is working.

## Proxmox

- Host IP: `192.168.10.50`
- Hostname seen in shell: `r515`
- VM: `docker01`
- `docker01` IP: `192.168.10.135`
- `docker01` IP is reserved in UniFi
- `docker01` is set to start at boot
- Home Assistant OS VM `haos` exists as VMID `101`

## Debian VM

- Username: `daniel`
- Docker installed
- Samba installed
- DuckDNS updater cron job installed
- Docker app/config path: `/srv/docker`
- Active Docker Compose file: `/srv/docker/docker-compose.yml`
- Config backups stored under `/mnt/storage/backups`

## Storage

3TB HDD is mounted in Debian at:

```text
/mnt/storage
```

Known folders:

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

## Docker Compose layout

Active Compose file:

```text
/srv/docker/docker-compose.yml
```

Current running containers:

| Container | Image | Notes |
| --- | --- | --- |
| `jellyfin` | `jellyfin/jellyfin:latest` | Media server, port `8096`; NVIDIA runtime enabled |
| `caddy` | `caddy:latest` | Reverse proxy, ports `80` and `443` |
| `uptime-kuma` | `louislam/uptime-kuma:2` | Monitoring dashboard, port `3001` |

Current NVIDIA-enabled Jellyfin and Uptime Kuma Compose services:

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
    ports:
      - "8096:8096"
    volumes:
      - /srv/docker/jellyfin/config:/config
      - /srv/docker/jellyfin/cache:/cache
      - /mnt/storage/media:/media

  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /srv/docker/caddy/Caddyfile:/etc/caddy/Caddyfile
      - /srv/docker/caddy/data:/data
      - /srv/docker/caddy/config:/config

  uptime-kuma:
    image: louislam/uptime-kuma:2
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - /srv/docker/uptime-kuma/data:/app/data
```

## Uptime Kuma

Uptime Kuma runs in Docker on `docker01`.

Access URL:

```text
http://192.168.10.135:3001
```

Initial setup was completed with Embedded MariaDB selected.

Recommended monitors to add:

| Monitor | Type | Target |
| --- | --- | --- |
| Jellyfin local | HTTP(s) | `http://192.168.10.135:8096` |
| Jellyfin public | HTTP(s) | `https://mediahubdaniel.duckdns.org` |
| Caddy local HTTP | HTTP(s) | `http://192.168.10.135` |
| HAOS | HTTP(s) | `http://192.168.10.127:8123` |
| Proxmox host | Ping | `192.168.10.50` |
| Debian Docker VM | Ping | `192.168.10.135` |
| Gateway / UDM Pro | Ping | `192.168.10.1` |

## Jellyfin

Jellyfin runs in Docker on `docker01`.

The host path:

```text
/mnt/storage/media
```

is mapped into the Jellyfin container as:

```text
/media
```

Jellyfin libraries should use:

```text
Movies: /media/movies
TV:     /media/tv
Music:  /media/music
```

## Caddy

Caddy runs in Docker and reverse proxies Jellyfin.

Current Caddyfile:

```caddyfile
{
    admin off
}

mediahubdaniel.duckdns.org {
    reverse_proxy jellyfin:8096
}
```

Caddy successfully obtained a certificate after WAN port forwards and the Caddyfile were fixed.

## Samba

Windows share:

```text
\\192.168.10.135\media
```

The share points to:

```text
/mnt/storage
```

Windows media copy locations:

```text
\\192.168.10.135\media\media\movies
\\192.168.10.135\media\media\tv
\\192.168.10.135\media\media\music
```

## Home Assistant

Home Assistant migration is paused in a safe state.

Current state:

- Raspberry Pi Home Assistant IP: `192.168.10.190`
- New HAOS VM: VMID `101`, name `haos`
- New HAOS VM IP: `192.168.10.127`
- HAOS VM MAC: `BC:24:11:5D:26:8C`
- New account was created and fresh HA dashboard is accessible.
- HACS installed.
- Matter Server installed.
- Terminal & SSH installed.
- Studio Code Server installed.
- Home Assistant Google Drive Backup installed.
- UniFi Network integration/add-on work completed by user.
- A fresh backup of the new HAOS VM was created.
- Decision: do not move the new HAOS VM to `192.168.10.190` yet. Leave it at `192.168.10.127` and keep the Raspberry Pi untouched as fallback.

Recommended later direction:

- Reserve `192.168.10.127` for MAC `BC:24:11:5D:26:8C` in UniFi.
- Keep the Raspberry Pi unchanged until the new VM is confirmed stable.
- Later decide whether to keep `192.168.10.127` permanently or move HAOS to `192.168.10.190` after shutting down/moving the Pi.

## NVIDIA / Jellyfin transcoding

Hardware installed in the R515:

- NVIDIA Quadro P400

Current status:

- Proxmox sees the P400.
- P400 is bound to `vfio-pci` on the Proxmox host.
- P400 was passed through to `docker01` as a raw PCI device.
- Debian `docker01` sees the P400.
- NVIDIA driver works inside Debian.
- NVIDIA Container Toolkit works with Docker using the explicit NVIDIA runtime.
- Jellyfin Compose uses `runtime: nvidia` and NVIDIA environment variables.
- The Jellyfin container can run `nvidia-smi`.
- Hardware transcoding is confirmed working: `/usr/lib/jellyfin-ffmpeg/ffmpeg` appeared in `nvidia-smi` during a forced transcode, using about 86 MiB of GPU memory.

Working Debian `nvidia-smi` result:

```text
NVIDIA-SMI 550.163.01             Driver Version: 550.163.01     CUDA Version: 12.4
GPU  Name                 Persistence-M | Bus-Id          Disp.A | Memory-Usage
0    Quadro P400                    Off | 00000000:00:10.0 Off | 2MiB / 2048MiB
```

Working Docker GPU test:

```bash
docker run --rm \
  --runtime=nvidia \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

Confirmed Jellyfin transcode GPU process:

```text
/usr/lib/jellyfin-ffmpeg/ffmpeg
GPU memory: about 86 MiB
```

## Backups

Current known backups:

- `/srv/docker`
- `/etc/samba/smb.conf`
- `/mnt/storage/backups/2026-07-13/srv-docker-after-p400.tar.gz` - 3.3 GB Docker/Jellyfin/Caddy config backup created after P400 hardware transcoding was confirmed.
- Fresh Home Assistant backup created on the new HAOS VM after HACS, Matter Server, Terminal & SSH, Studio Code Server, Google Drive Backup, and UniFi were rebuilt.

Still needed:

- Copy `/etc/samba/smb.conf` into `/mnt/storage/backups/2026-07-13/smb-after-p400.conf` if it was not created yet.

Recommended next backup improvement:

- Add a repeatable backup script.
- Copy backups off the same 3TB HDD eventually.
- Keep at least one backup outside the R515.
