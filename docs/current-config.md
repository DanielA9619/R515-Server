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
- VM: `docker01`
- `docker01` IP: `192.168.10.135`
- `docker01` IP is reserved in UniFi
- `docker01` is set to start at boot
- Planned additional VM: dedicated Home Assistant OS VM

## Debian VM

- Username: `daniel`
- Docker installed
- Samba installed
- DuckDNS updater cron job installed
- Docker app/config path: `/srv/docker`
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

Current Home Assistant is still on the Raspberry Pi and is not fully built out yet.

Current status:

- Backup is having trouble.
- Only around 3 add-ons are currently installed.
- Because the setup is still small, rebuilding cleanly on a new HAOS VM is acceptable and may be simpler than fighting the backup problem.

Recommended direction:

- Create a fresh HAOS VM in Proxmox.
- Rebuild Home Assistant manually.
- Keep the Raspberry Pi unchanged until the new VM is confirmed working.
- If possible, manually record or screenshot key integrations, add-ons, dashboards, and automations before rebuilding.

## NVIDIA / Jellyfin transcoding

Hardware installed in the R515:

- NVIDIA Quadro P400

Current test from inside Debian VM `docker01`:

```bash
lspci | grep -i nvidia
```

Result:

```text
No output
```

Current test from inside Debian VM `docker01`:

```bash
nvidia-smi
```

Result:

```text
-bash: nvidia-smi: command not found
```

Interpretation:

- The P400 is not currently visible inside the Debian VM.
- NVIDIA drivers are not installed inside the Debian VM.
- Before Jellyfin hardware transcoding can be configured, the GPU needs to be passed through to `docker01` or another architecture needs to be chosen.

## Backups

Current known backups:

- `/srv/docker`
- `/etc/samba/smb.conf`

Recommended next backup improvement:

- Add a repeatable backup script.
- Copy backups off the same 3TB HDD eventually.
- Keep at least one backup outside the R515.
